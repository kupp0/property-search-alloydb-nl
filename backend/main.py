# backend/main.py
import os
import re
import base64
import psycopg2
import vertexai
import google.auth
from vertexai.language_models import TextEmbeddingModel
from vertexai.vision_models import MultiModalEmbeddingModel
from google.cloud import discoveryengine_v1beta as discoveryengine
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Explicitly find and load the .env file from the backend directory
# This makes the app robust, regardless of where it's started from.
backend_dir = os.path.dirname(os.path.abspath(__file__))
dotenv_path = os.path.join(backend_dir, '.env')
load_dotenv(dotenv_path=dotenv_path)

# ==============================================================================
# CONFIGURATION & INITIALIZATION
# ==============================================================================

app = FastAPI(title="AlloyDB Property Search (Local Demo)")

# Configure CORS to allow the local React frontend to communicate with this backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Google Cloud Clients
# Initialize variables to None first to handle failures gracefully
mm_model = None
gemini_text_model = None
search_client = None

try:
    PROJECT_ID = os.getenv("GCP_PROJECT_ID") or os.environ.get("GOOGLE_CLOUD_PROJECT")
    LOCATION = os.getenv("GCP_LOCATION", "europe-west1")

    # Add a hard failure if Project ID is not found. This is the most common startup error.
    if not PROJECT_ID:
        raise ValueError("GCP_PROJECT_ID not found. Please ensure it is set in your backend/.env file.")

    # --- EXPLICIT CREDENTIALS HANDLING ---
    # This is the key fix. On a GCE VM, the SDK defaults to the VM's service account.
    # We must explicitly load the user's "Application Default Credentials" (ADC)
    # to override this and use the permissions of the logged-in user.
    credentials, _ = google.auth.default(
        scopes=['https://www.googleapis.com/auth/cloud-platform']
    )

    # 1. Initialize Vertex AI SDK
    # Pass the user's credentials to override the VM's service account.
    vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
    
    # 2. Load Models
    print("Initializing models...")
    # Removed ImageGenerationModel
    mm_model = MultiModalEmbeddingModel.from_pretrained("multimodalembedding") # image embeddings
    gemini_text_model = TextEmbeddingModel.from_pretrained("gemini-embedding-001") # text embeddings
    print("Models initialized successfully.")
    
    # 3. Initialize Vertex AI Search Client
    search_client = discoveryengine.SearchServiceClient()
    
except Exception as e:
    print(f"Warning: Google Cloud initialization failed. AI features may not work.\nError: {e}")
    # The variables remain None if initialization failed


# ==============================================================================
# DATA MODELS
# ==============================================================================

class SearchRequest(BaseModel):
    query: str
    mode: str = "nl2sql"  # Options: 'nl2sql', 'semantic', 'visual', 'vertex_search'

# Removed ImageRequest class

# ==============================================================================
# DATABASE HELPERS
# ==============================================================================

def get_db_connection():
    """
    Establishes a connection to the AlloyDB instance via the local Auth Proxy.
    """
    try:
        # print(f"Connecting to DB {os.getenv('DB_NAME')} as {os.getenv('DB_USER')}...")
        return psycopg2.connect(
            dbname=os.getenv("DB_NAME", "postgres"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD"),
            host="127.0.0.1", 
            port="5432"
        )
    except Exception as e:
        print(f"DB Connection Error: {e}")
        raise HTTPException(status_code=500, detail=f"Database Connection Failed: {e}")


# ==============================================================================
# API ENDPOINTS
# ==============================================================================

@app.post("/api/search")
async def search_properties(request: SearchRequest):
    conn = get_db_connection()
    cursor = conn.cursor()
    results = []
    display_sql = ""

    try:
        # ---------------------------------------------------------
        # MODE 4: VERTEX AI SEARCH (Managed Service)
        # ---------------------------------------------------------
        if request.mode == "vertex_search":
            if not search_client:
                 raise HTTPException(500, "Vertex Search client not initialized.")

            data_store_id = os.getenv("VERTEX_SEARCH_DATA_STORE_ID")
            if not data_store_id:
                raise HTTPException(500, "VERTEX_SEARCH_DATA_STORE_ID is missing in .env")

            serving_config = search_client.serving_config_path(
                project=PROJECT_ID,
                location="global",
                data_store=data_store_id,
                serving_config="default_config",
            )

            response = search_client.search(
                discoveryengine.SearchRequest(
                    serving_config=serving_config,
                    query=request.query,
                    page_size=10,
                )
            )

            for result in response.results:
                # Convert MapComposite to standard dict
                data = dict(result.document.struct_data)
                # Ensure image field exists for frontend compatibility
                if "image_gcs_uri" not in data: data["image_gcs_uri"] = None
                results.append(data)

            display_sql = f"// MANAGED SERVICE CALL\n// Vertex AI Search (Agent Builder)\n// Query: '{request.query}'\n// Strategy: Keyword + Semantic Hybrid (Auto)"
            
            # Return early as we don't need DB connection anymore for this mode
            return {"listings": results, "sql": display_sql}


        # ---------------------------------------------------------
        # MODE 1: VISUAL SEARCH (Text-to-Image Embedding)
        # ---------------------------------------------------------
        elif request.mode == "visual":
            if not mm_model: 
                raise HTTPException(500, "Multimodal model not initialized")
            
            print(f"Generating visual embedding for: '{request.query}'")
            embeddings = mm_model.get_embeddings(
                contextual_text=request.query, 
                dimension=1408
            )
            vector_str = str(embeddings.text_embedding)
            
            # Visual search queries the image_embedding column.
            sql = f"""
            SELECT id, title, description, price, city, bedrooms, image_gcs_uri
            FROM "search".property_listings 
            ORDER BY image_embedding <=> '{vector_str}' 
            LIMIT 20;
            """
            
            cursor.execute(sql)
            display_sql = f"SELECT ... ORDER BY image_embedding <=> '[{vector_str[:20]}...]'::vector (1408 dim)"

            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                results = [dict(zip(columns, row)) for row in cursor.fetchall()]


        # ---------------------------------------------------------
        # MODE 2: SEMANTIC SEARCH (Text-to-Text Embedding - GEMINI)
        # ---------------------------------------------------------
        elif request.mode == "semantic":
            # Safety check for the Gemini model
            if not gemini_text_model:
                raise HTTPException(500, "Gemini Text model not initialized")

            print(f"Generating Gemini text embedding for: '{request.query}'")
            # 1. Generate embedding in Python using new model (defaults to 768 dimensions)
            embeddings = gemini_text_model.get_embeddings([request.query])
            vector_str = str(embeddings[0].values)

            # 2. Build SQL with the embedded vector
            sql = f"""
            SELECT id, title, description, price, city, bedrooms, image_gcs_uri
            FROM "search".property_listings 
            ORDER BY description_embedding <=> '{vector_str}' 
            LIMIT 20;
            """
            
            display_sql = f"// Model: gemini-embedding-001 (768 dim)\nSELECT ... ORDER BY description_embedding <=> '[{vector_str[:20]}...]'::vector"
           
            # SQL string is complete, no parameters needed
            cursor.execute(sql)
            
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                results = [dict(zip(columns, row)) for row in cursor.fetchall()]


        # ---------------------------------------------------------
        # MODE 3: NL2SQL (Generative SQL via AlloyDB AI)
        # ---------------------------------------------------------
        else:
            print(f"Generating SQL via AlloyDB AI for: '{request.query}'")
            # Note: This mode still relies on the model defined in your AlloyDB configuration
            cursor.execute("SELECT alloydb_ai_nl.get_sql('property_search_config', %s) ->> 'sql'", (request.query,))
            row = cursor.fetchone()
            gen_sql = row[0] if row else None
            
            if not gen_sql: 
                return {"listings": [], "sql": "Could not generate SQL from query."}

            # SQL cleanup heuristics for demo purposes
            gen_sql = gen_sql.strip().rstrip(';')
            if "FROM" in gen_sql.upper():
                gen_sql = gen_sql.replace("SELECT ", "SELECT image_gcs_uri, ", 1)
            
            final_sql = re.sub(r"LIMIT\s+\d+", "LIMIT 20", gen_sql, flags=re.IGNORECASE)
            if "LIMIT" not in final_sql.upper(): 
                final_sql += " LIMIT 20"
            
            display_sql = final_sql
            # print(f"Executing NL2SQL: {final_sql}")
            cursor.execute(final_sql)
            
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                results = [dict(zip(columns, row)) for row in cursor.fetchall()]


        return {"listings": results, "sql": display_sql}

    except psycopg2.Error as e:
        print(f"Database Error: {e.pgcode} - {e.pgerror}")
        return {"listings": [], "sql": f"Database Error: {e.pgerror}"}
    except Exception as e:
        print(f"Backend Error: {e}")
        return {"listings": [], "sql": f"Backend Error: {str(e)}"}
        # Provide a more specific error if a model wasn't initialized
        if (request.mode == "visual" and not mm_model) or \
           (request.mode == "semantic" and not gemini_text_model):
            return {"listings": [], "sql": "Backend Error: A required AI model failed to initialize at startup. Check backend logs."}
        return {"listings": [], "sql": f"An unexpected error occurred: {str(e)}"}
        
    finally:
        # Ensure connection is closed even if an error occurs
        if cursor: cursor.close()
        if conn: conn.close()

# Removed /api/generate-image endpoint