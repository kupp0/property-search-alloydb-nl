# backend/export_for_vertex.py
import os
import json
import psycopg2
from dotenv import load_dotenv
import os

# Find and load the .env file from the backend directory
backend_dir = os.path.dirname(os.path.abspath(__file__))
dotenv_path = os.path.join(backend_dir, '.env')
load_dotenv(dotenv_path=dotenv_path)

def get_db_connection():
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME", "postgres"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        host="127.0.0.1", port="5432"
    )

def export_data():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Fetch all columns needed for search
    cursor.execute("""
        SELECT id, title, description, price, city, bedrooms, image_gcs_uri 
        FROM "search".property_listings
    """)
    
    rows = cursor.fetchall()
    columns = [desc[0] for desc in cursor.description]
    
    output_file = "alloydb_export.jsonl"
    
    with open(output_file, 'w') as f:
        for row in rows:
            item = dict(zip(columns, row))
            # Convert Decimal/Integers to standard JSON types
            item['price'] = float(item['price'])
            item['id'] = str(item['id'])
            
            # Vertex AI Search expects a specific format for the document ID
            vertex_doc = {
                "id": item['id'],
                "structData": item,
                "content": {
                    "mimeType": "text/plain",
                    "uri": item['image_gcs_uri'] or "http://placeholder"
                }
            }
            f.write(json.dumps(vertex_doc) + "\n")
            
    print(f"✅ Exported {len(rows)} rows to {output_file}")
    print("👉 Download this file and upload it to Vertex AI Agent Builder!")

if __name__ == "__main__":
    export_data()