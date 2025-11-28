/*
===================================================================================
ALLOYDB AI: DATABASE & SCHEMA BOOTSTRAP
===================================================================================

This script initializes the foundation for the Semantic Search Demo.
It performs the following critical operations:

1. SCHEMA SETUP: Creates a dedicated "search" schema to keep the workspace clean.
2. EXTENSIONS: Enables Google ML, Vector, ScaNN, and AI Natural Language extensions.
3. TABLE DDL: Creates the `property_listings` table with:
   - Automatic Text Embeddings (using `generative-embedding-001` via database trigger).
   - Placeholder for Image Embeddings (populated later via Python).
4. DATA LOAD: Inserts sample real estate data for Switzerland.
5. INDEXING: Creates high-performance ScaNN indexes.
   * NOTE: Uses MANUAL mode because the dataset is small (<10k rows).

PRE-REQUISITES:
- Ensure the Vertex AI API is enabled in your Google Cloud Project.
- Ensure the AlloyDB Service Account has "Vertex AI User" permissions.
===================================================================================
*/

-- 1. SCHEMA INITIALIZATION
-- ===================================================================================

-- Create a clean slate for the demo
DROP SCHEMA IF EXISTS "search" CASCADE;
CREATE SCHEMA "search";

-- Set the path so we don't have to type "search." constantly
SET search_path TO "search", public;


-- 2. EXTENSION MANAGEMENT
-- ===================================================================================

-- Enable the Google ML Integration (Bridge to Vertex AI)
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;

-- Enable pgvector (Base vector data type support)
CREATE EXTENSION IF NOT EXISTS vector CASCADE;

-- Enable AlloyDB ScaNN (High-performance vector indexing)
CREATE EXTENSION IF NOT EXISTS alloydb_scann CASCADE;

-- Enable Natural Language Support (For the NL2SQL features configured later)
CREATE EXTENSION IF NOT EXISTS alloydb_ai_nl CASCADE;

-- Update extensions to ensure latest versions are active
ALTER EXTENSION alloydb_ai_nl UPDATE;

-- VERIFICATION: Check integration status
-- Expectation: Should show valid version and model support enabled
SELECT extname, extversion FROM pg_extension WHERE extname = 'google_ml_integration';
SHOW google_ml_integration.enable_model_support;

-- TEST: Sanity check the embedding connection to Gemini
-- If this fails, check your IAM permissions.
SELECT google_ml.embedding(
   model_id => 'gemini-embedding-001',
   content => 'Sanity check for Vertex AI connection'
) AS test_vector;


-- 3. TABLE CREATION
-- ===================================================================================

DROP TABLE IF EXISTS "search".property_listings CASCADE;

CREATE TABLE "search".property_listings (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(12, 2) NOT NULL,
    bedrooms INT,
    city VARCHAR(100),
    image_gcs_uri TEXT,
    -- COLUMN A: Text Embeddings (Managed by Database)
    -- Automatically generates a 3072-dim vector when you insert text into 'description'.
    description_embedding VECTOR(3072) GENERATED ALWAYS AS (
      embedding('gemini-embedding-001', description)
    ) STORED,
    -- COLUMN B: Image Embeddings (Managed by Application)
    -- Populated by 'bootstrap_images.py' using the Multimodal model (3072 dims).
    image_embedding VECTOR(1408) 
);


-- 4. SAMPLE DATA INSERTION
-- ===================================================================================
-- Embeddings for 'description' are generated automatically upon insertion. Use Gemini to customize the sample data to your cities and add more samples if you like.
-- Image URIs and Image Embeddings are left NULL here (populated in the Python step).

INSERT INTO "search".property_listings (title, description, price, bedrooms, city) VALUES
-- ZURICH
('Sunny Apartment in Zurich-Oerlikon', 'Bright 3.5 room apartment located near the Hallenstadion. Excellent public transport connections to the airport and city center. diverse neighborhood with many shops.', 2800.00, 2, 'Zurich'),
('Industrial Style Loft in Zurich West', 'Trendy open-space loft in a converted factory. High ceilings, exposed concrete, and a rooftop terrace. Perfect for young creatives or a startup couple.', 3900.00, 1, 'Zurich'),
('Exclusive Penthouse on Zurichberg', 'Top-floor residence with breathtaking views of the city and the Alps. Features a private elevator, fireplace, and a wrap-around terrace. Absolute privacy and luxury.', 9500.00, 3, 'Zurich'),
('Student Room in Shared Flat', 'Affordable room in a lively 4-person WG in Zurich-Wiedikon. Close to bars, cafes, and nightlife. Shared kitchen and living room.', 850.00, 1, 'Zurich'),
('Historic Townhouse in Niederdorf', 'Live in the middle of the old town. A unique 4-story house with exposed beams and historic charm. Steps away from the Limmat river and Grossmunster.', 5200.00, 3, 'Zurich'),

-- GENEVA
('Modern Flat near United Nations', 'Sleek and secure 2-bedroom apartment walking distance from the UN headquarters. Concierge service and gym in the building. Ideal for diplomats.', 4800.00, 2, 'Geneva'),
('Spacious Family Apartment in Champel', 'Quiet and green neighborhood. Large 5-room apartment with a renovated kitchen and two balconies. Close to parks and top-rated schools.', 6200.00, 3, 'Geneva'),
('Budget Studio near Cornavin', 'Small but functional studio right next to the main train station. Perfect for a commuter needing a pied-à-terre in the city center.', 1600.00, 0, 'Geneva'),

-- LAUSANNE
('Lake View Apartment in Ouchy', 'Stunning 3-bedroom flat right on the lakeside promenade. Wake up to views of the French Alps across Lake Geneva. elegant parquet floors.', 5900.00, 3, 'Lausanne'),
('Attic Apartment near Cathedral', 'Charming top-floor flat with sloping ceilings in the heart of Lausanne. No elevator, but offers a fantastic view over the rooftops.', 2100.00, 1, 'Lausanne'),

-- BASEL
('Architectural Gem near Roche Tower', 'Modern, minimalist apartment designed by a famous architect. Flooded with light, featuring high-end appliances. Walking distance to Roche campus.', 3400.00, 2, 'Basel'),
('Riverfront Flat with Rhine View', 'Directly on the Rhine river. Watch the swimmers in summer from your balcony. Spacious living room and classic herringbone flooring.', 3100.00, 2, 'Basel'),

-- BERN
('Medieval Charm in Bern Old Town', 'Located in a UNESCO World Heritage building. Sandstone walls, cellar storage, and view of the Zytglogge. A truly unique living experience.', 2600.00, 2, 'Bern'),
('Modern Garden Apartment in Kirchenfeld', 'Ground floor apartment with a large private garden in the diplomat quarter. Quiet, secure, and very prestigious neighborhood.', 4500.00, 3, 'Bern'),

-- MOUNTAINS & OTHER
('Luxury Chalet in Zermatt', 'Traditional wooden chalet with modern interior. Unobstructed view of the Matterhorn. Includes a sauna and ski boot heater. Available for long-term seasonal rent.', 12000.00, 4, 'Zermatt'),
('Lake Lugano Villa with Pool', 'Mediterranean style villa in Ticino. Features a lush garden with palm trees, an infinity pool, and private lake access. Feel like you are on vacation every day.', 14500.00, 5, 'Lugano'),
('Cozy Apartment in Old Lucerne', 'Right on the Reuss river with a view of the Chapel Bridge. Historic building with modern amenities. Walkable to everything.', 2900.00, 2, 'Lucerne'),
('Remote Cabin in Grisons', 'Secluded mountain hut for nature lovers. Simple living, wood stove heating, and surrounded by forest. Accessible by 4x4 in winter.', 1200.00, 1, 'Chur'),
('Commuter Friendly Flat in Olten', 'Practical and newly built apartment right at the train station hub. reach Zurich, Bern, or Basel in under 30 minutes. High standard finishing.', 1950.00, 2, 'Olten'),
('Design Loft in St. Gallen', 'Close to the Abbey library. Open concept living in a converted textile warehouse. High ceilings and huge windows.', 2300.00, 1, 'St. Gallen');


/* ===================================================================================
 STOP! INTERMEDIATE STEP REQUIRED
===================================================================================
 At this stage, run the Python script: /backend/bootstrap_images.py
 
 This script will:
 1. Generate images using Vertex AI Imagen.
 2. Upload them to Google Cloud Storage.
 3. Calculate Visual Embeddings.
 4. Update the database rows below with the image URI and image_vector.
 
 Once the Python script is finished, proceed to Step 5.
===================================================================================
*/

-- Verify data exists
SELECT count(*) as property_count FROM "search".property_listings;


-- 5. INDEX CREATION (ScaNN)
-- ===================================================================================
-- Index 1: Text Description Index
-- Uses Cosine Distance for semantic similarity.
CREATE INDEX idx_scann_property_desc ON "search".property_listings
USING scann (description_embedding)
WITH (
    -- 'auto' mode requires ~10k rows. For this demo, we force MANUAL mode.
    mode = 'MANUAL',
    num_leaves = 1,     -- 1 partition is optimal for < 1000 rows.
    quantizer = 'SQ8'   -- Standard quantization for balance of speed/accuracy.
);

-- Index 2: Visual Search Index
-- Indexes the Multi-modal embedding column.
CREATE INDEX idx_scann_image_search ON "search".property_listings
USING scann (image_embedding)
WITH (
    mode = 'MANUAL',
    num_leaves = 1,     -- Kept at 1 to ensure stability with small demo dataset.
    quantizer = 'SQ8'
);


-- 6. VALIDATION QUERIES
-- ===================================================================================

-- Test A: Simple Semantic Search
-- Finds "Student" vibes even without the word "Student" (looking for "Quiet", "Study").
SELECT title, description, price, city
FROM "search".property_listings
ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'a quiet place to study near by University')::vector
LIMIT 3;

-- Test B: Hybrid Search (Semantic + Filters)
-- Finds modern apartments, specifically in Zurich, specifically under 15k.
SELECT id, title, price, city
FROM "search".property_listings
WHERE price < 15000.00
  AND city = 'Zurich'
ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'a modern apartment for a professional working in the city')::vector
LIMIT 3;

-- Test C: Concept/Vibe Search
-- "Live near water" -> matches descriptions mentioning lakes or rivers.
SELECT
    title,
    price,
    city,
    -- Show the actual distance score (0 is perfect match, 1 is no match)
    description_embedding <=> embedding('gemini-embedding-001', 'I want to live near the water')::vector AS cosine_distance
FROM "search".property_listings
ORDER BY cosine_distance ASC
LIMIT 3;