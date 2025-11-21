-- ===================================================================================
-- AlloyDB AI: Semantic Search Demo using a Dedicated Schema
--
-- This script sets up a complete semantic search demonstration inside a dedicated
-- 'search' schema. It performs the following steps:
-- 1. Creates the 'search' schema.
-- 2. Sets the session's search path to prioritize the 'search' schema.
-- 3. Enables the necessary AlloyDB extensions for AI and vector operations.
-- 4. Creates a table within the 'search' schema with an auto-generating embedding column.
-- 5. Inserts sample data (embeddings are created automatically).
-- 6. Creates a dedicated, high-performance ScaNN index for fast vector search.
-- 7. Provides example queries to test the functionality.
--
-- ===================================================================================

-- STEP 1: Create Schema and Set Search Path
-- -----------------------------------------------------------------------------------
-- Create a dedicated schema to organize all our search-related objects.
Drop SCHEMA search CASCADE;
CREATE SCHEMA IF NOT EXISTS "search";

SET search_path TO "search", public;

-- -----------------------------------------------------------------------------------
-- IMPORTANT: Prerequisites
/*
 1) Enable VertexAI API 
 2) If needed, Grant Vertex AI User to the AlloyDB SA: 

*/
-- -----------------------------------------------------------------------------------


-- STEP 2: Enable Required Extensions
-- -----------------------------------------------------------------------------------
-- Enable `google_ml_integration` to call Vertex AI and use the `scann` index.
-- Enable `vector` to support the VECTOR data type.
-- These extensions are installed once per database.
CREATE EXTENSION IF NOT EXISTS google_ml_integration;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS alloydb_scann;

-- Install the Natural Language extension
CREATE EXTENSION IF NOT EXISTS alloydb_ai_nl CASCADE;

-- Verify installation
SELECT * FROM pg_available_extensions WHERE name = 'alloydb_ai_nl';
ALTER EXTENSION alloydb_ai_nl UPDATE; -- Ensure latest version

-- check version:
SELECT extversion FROM pg_extension WHERE extname = 'google_ml_integration';
show google_ml_integration.enable_model_support;


-- TEST Embedding model call
SELECT
 google_ml.embedding( 
   model_id => 'gemini-embedding-001',
   content => 'A stunning, newly-renovated loft in the heart of Zurich. Features floor-to-ceiling windows, an open-plan kitchen, perfect for a single professional or couple.');

-- STEP 3: Create the Property Listings Table
-- -----------------------------------------------------------------------------------
-- Create the table within the "search" schema. The `GENERATED ALWAYS AS` clause
-- automates the creation of embeddings using the gemini-embedding-001 model.
-- We use a fully qualified name for robustness.
DROP TABLE IF EXISTS "search".property_listings CASCADE;

CREATE TABLE "search".property_listings (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(12, 2) NOT NULL,
    bedrooms INT,
    city VARCHAR(100),
   image_gcs_uri TEXT,
    description_embedding VECTOR(3072) GENERATED ALWAYS AS (
      embedding('gemini-embedding-001', description)
    ) STORED,
     image_embedding VECTOR(1408) -- for multi modal vector embeddings including images
);


-- STEP 4: Insert Sample Data (Embeddings Generated Automatically)
-- -----------------------------------------------------------------------------------
-- Insert data into the table. The database handles embedding generation automatically.

-- this is without GCS image URI. This needs to be populated by bootstrapping_images.py program. 

INSERT INTO "search".property_listings (title, description, price, bedrooms, city) VALUES
-- ZURICH (Diverse mix of luxury, student, and family)
('Sunny Apartment in Zurich-Oerlikon', 'Bright 3.5 room apartment located near the Hallenstadion. Excellent public transport connections to the airport and city center. diverse neighborhood with many shops.', 2800.00, 2, 'Zurich'),
('Industrial Style Loft in Zurich West', 'Trendy open-space loft in a converted factory. High ceilings, exposed concrete, and a rooftop terrace. Perfect for young creatives or a startup couple.', 3900.00, 1, 'Zurich'),
('Exclusive Penthouse on Zurichberg', 'Top-floor residence with breathtaking views of the city and the Alps. Features a private elevator, fireplace, and a wrap-around terrace. Absolute privacy and luxury.', 9500.00, 3, 'Zurich'),
('Student Room in Shared Flat', 'Affordable room in a lively 4-person WG in Zurich-Wiedikon. Close to bars, cafes, and nightlife. Shared kitchen and living room.', 850.00, 1, 'Zurich'),
('Historic Townhouse in Niederdorf', 'Live in the middle of the old town. A unique 4-story house with exposed beams and historic charm. Steps away from the Limmat river and Grossmunster.', 5200.00, 3, 'Zurich'),

-- GENEVA (International, luxury, and commuter)
('Modern Flat near United Nations', 'Sleek and secure 2-bedroom apartment walking distance from the UN headquarters. Concierge service and gym in the building. Ideal for diplomats.', 4800.00, 2, 'Geneva'),
('Spacious Family Apartment in Champel', 'Quiet and green neighborhood. Large 5-room apartment with a renovated kitchen and two balconies. Close to parks and top-rated schools.', 6200.00, 3, 'Geneva'),
('Budget Studio near Cornavin', 'Small but functional studio right next to the main train station. Perfect for a commuter needing a pied-à-terre in the city center.', 1600.00, 0, 'Geneva'),

-- LAUSANNE (Views and student life)
('Lake View Apartment in Ouchy', 'Stunning 3-bedroom flat right on the lakeside promenade. Wake up to views of the French Alps across Lake Geneva. elegant parquet floors.', 5900.00, 3, 'Lausanne'),
('Attic Apartment near Cathedral', 'Charming top-floor flat with sloping ceilings in the heart of Lausanne. No elevator, but offers a fantastic view over the rooftops.', 2100.00, 1, 'Lausanne'),

-- BASEL (Art and pharma focus)
('Architectural Gem near Roche Tower', 'Modern, minimalist apartment designed by a famous architect. Flooded with light, featuring high-end appliances. Walking distance to Roche campus.', 3400.00, 2, 'Basel'),
('Riverfront Flat with Rhine View', 'Directly on the Rhine river. Watch the swimmers in summer from your balcony. Spacious living room and classic herringbone flooring.', 3100.00, 2, 'Basel'),

-- BERN (Capital and old town)
('Medieval Charm in Bern Old Town', 'Located in a UNESCO World Heritage building. Sandstone walls, cellar storage, and view of the Zytglogge. A truly unique living experience.', 2600.00, 2, 'Bern'),
('Modern Garden Apartment in Kirchenfeld', 'Ground floor apartment with a large private garden in the diplomat quarter. Quiet, secure, and very prestigious neighborhood.', 4500.00, 3, 'Bern'),

-- MOUNTAIN & OTHER (For "vacation" or "nature" searches)
('Luxury Chalet in Zermatt', 'Traditional wooden chalet with modern interior. Unobstructed view of the Matterhorn. Includes a sauna and ski boot heater. Available for long-term seasonal rent.', 12000.00, 4, 'Zermatt'),
('Lake Lugano Villa with Pool', 'Mediterranean style villa in Ticino. Features a lush garden with palm trees, an infinity pool, and private lake access. Feel like you are on vacation every day.', 14500.00, 5, 'Lugano'),
('Cozy Apartment in Old Lucerne', 'Right on the Reuss river with a view of the Chapel Bridge. Historic building with modern amenities. Walkable to everything.', 2900.00, 2, 'Lucerne'),
('Remote Cabin in Grisons', 'Secluded mountain hut for nature lovers. Simple living, wood stove heating, and surrounded by forest. Accessible by 4x4 in winter.', 1200.00, 1, 'Chur'),
('Commuter Friendly Flat in Olten', 'Practical and newly built apartment right at the train station hub. reach Zurich, Bern, or Basel in under 30 minutes. High standard finishing.', 1950.00, 2, 'Olten'),
('Design Loft in St. Gallen', 'Close to the Abbey library. Open concept living in a converted textile warehouse. High ceilings and huge windows.', 2300.00, 1, 'St. Gallen');


/* 
########## Create Image creation with Gemini and storage outside of AlloyDB on GCS with only the GCS UI in the table and multimodel embeddings outside of alloyDB and only stored as vector store in the columne + vector index SCaNN after adding the embeddings based on images to the table

navigate to to /backend/bootstrap_images.py and continue. You can also skip this if you don't want to have visual search enabled. 

*/

SELECT * FROM search.property_listings;
-- STEP 5: Create a Dedicated AlloyDB ScaNN Index
-- -----------------------------------------------------------------------------------
-- Create a native ScaNN index on the embeddings column for maximum query performance.
-- 'cosine_distance' is the recommended metric for comparing semantic text embeddings.
-- here we use auto mode: Create a ScaNN index in AUTO mode (https://docs.cloud.google.com/alloydb/docs/ai/create-scann-index#create-scann-index-automatic)
CREATE INDEX idx_scann_property_desc ON "search".property_listings
USING scann (description_embedding)
--WITH (mode = 'auto'); --requires more sample data rows. minimum 1k
WITH (
    mode = 'MANUAL',
    num_leaves = 1,     -- Minimum number of partitions
    quantizer = 'SQ8'   -- Default and a good starting quantizer
);


-- 2nd Create a ScaNN index on the Multi modal embedding column for fast visual search
CREATE INDEX idx_scann_image_search ON "search".property_listings
USING scann (image_embedding)
WITH (
    num_leaves = 10,
    quantizer = 'SQ8'
);

/*
mode = 'MANUAL': This tells AlloyDB you are providing the tuning parameters yourself.
description_embedding cosine: Specifies the column and the distance metric to use (cosine similarity is common for text embeddings).
num_leaves = 1: This is the number of partitions (clusters) the data will be divided into. Since you have very few rows, a single partition is the most sensible minimum value.
quantizer = 'SQ8': This specifies the quantization method. SQ8 is the default and offers a good balance between performance and recall. Other options include FLAT (highest recall, potentially slower) and AH (more compressed).
Important Considerations for a Demo:

Bypassing Row Limit: This manual configuration with num_leaves = 1 should bypass the 10,000-row requirement you encountered with mode = 'auto'.
Not for Performance Testing: Creating a ScaNN index on only 6 rows will not demonstrate any performance advantages. ScaNN and other Approximate Nearest Neighbor (ANN) indexes shine with datasets of at least thousands to millions of rows. On a 6-row table, a simple sequential scan (exact search) would be faster.
*/

-- STEP 6: Example Queries
-- -----------------------------------------------------------------------------------
-- The setup is complete. You can now run these example queries manually.
-- The cosine distance operator `<=>` will automatically leverage the ScaNN index.
-- -----------------------------------------------------------------------------------

-- EXAMPLE QUERY 1: Simple Semantic Search
-- Find a property suitable for a student, using natural language.
SELECT title, description, price, city
FROM "search".property_listings
ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'a quiet place to study near by University')::vector
LIMIT 3;


-- EXAMPLE QUERY 2: Hybrid Search (Semantic + Filters)
-- Find a modern, but not lakeside, property in Zurich for a professional.
SELECT id, title, price, city
FROM "search".property_listings
WHERE price < 15000.00
  AND city = 'Zurich'
ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'a modern apartment for a professional working in the city')::vector
LIMIT 3;

-- EXAMPLE QUERY 3: Concept-Based Search
-- Find a property based on a lifestyle concept (living near water).
SELECT title, description, price, city
FROM "search".property_listings
ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'I want to live near the water')::vector
LIMIT 3;

/* Put the cosine distance into the selection field. 
Cosine distance = 0: Perfect similarity (vectors point in the exact same direction).
1: Orthogonal / no similarity.
*/

SELECT
    title,
    description,
    price,
    city,
    description_embedding <=> embedding('gemini-embedding-001', 'I want to live near the water')::vector AS cosine_distance
FROM "search".property_listings
ORDER BY cosine_distance ASC
LIMIT 3;




