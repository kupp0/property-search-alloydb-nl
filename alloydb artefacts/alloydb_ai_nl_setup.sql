/*
===================================================================================
ALLOYDB AI: COMPLETE NATURAL LANGUAGE CONFIGURATION
===================================================================================
Combined Setup & Hardening Script
-----------------------------------------------------------------------------------
1. SETUP:       Extensions and Configuration creation.
2. CONTEXT:     Schema registration and AI Context Tuning (Case sensitivity/Soft filters).
3. CONCEPTS:    Mapping columns to real-world types (e.g., Cities).
4. TEMPLATES:   The "Grammar" (Hybrid Search, Parameterized queries).
5. FRAGMENTS:   The "Vocabulary" (Adjectives, Negations, Business Rules).
===================================================================================
*/

-- 0. SETUP & INITIALIZATION
-- ===================================================================================
SET search_path TO "search", public;

-- Install/Update the Natural Language extension
CREATE EXTENSION IF NOT EXISTS alloydb_ai_nl CASCADE;
ALTER EXTENSION alloydb_ai_nl UPDATE;

-- Create the configuration holder
SELECT alloydb_ai_nl.g_create_configuration(
  'property_search_config'
);

-- 1. SCHEMA CONTEXT & TUNING
-- ===================================================================================
-- Register the table so the AI knows it exists
SELECT alloydb_ai_nl.g_manage_configuration(
  operation        => 'register_table_view',
  configuration_id_in => 'property_search_config',
  table_views_in    => ARRAY['search.property_listings']
);

-- Generate the baseline context from the database schema
SELECT alloydb_ai_nl.generate_schema_context(
  'property_search_config',
  TRUE -- Overwrite existing
);

-- [TUNING] Fix Case Sensitivity for Cities
-- Instructs AI that 'zurich' input should match 'Zurich' database value via ILIKE
SELECT alloydb_ai_nl.update_generated_column_context(
  'search.property_listings.city',
  'The city name stored in Title Case (e.g. Zurich, Geneva). When filtering by city, ALWAYS convert input to Title Case or use the ILIKE operator to ignore case.'
);

-- [TUNING] Fix Empty Results for Amenities
-- Instructs AI to use Vector search for amenities (pool, view) rather than strict WHERE clauses
SELECT alloydb_ai_nl.update_generated_column_context(
  'search.property_listings.description',
  'Contains details like pools, balconies, or views. Prefer using vector search / ordering for these features rather than strict WHERE clauses to avoid empty results.'
);

-- APPLY the tuned context to the active configuration
SELECT alloydb_ai_nl.apply_generated_schema_context('property_search_config');


-- 2. CONCEPT TYPES & VALUE INDEXING
-- ===================================================================================
-- Associate 'city' column with the built-in 'city_name' concept
SELECT alloydb_ai_nl.associate_concept_type(
  column_names_in => 'search.property_listings.city',
  concept_type_in => 'city_name',
  nl_config_id_in => 'property_search_config'
);

-- Generate and Apply Concept associations
SELECT alloydb_ai_nl.generate_concept_type_associations('property_search_config');
SELECT alloydb_ai_nl.apply_generated_concept_type_associations('property_search_config');

-- Create Value Index (Critical for looking up specific strings like "Zurich")
SELECT alloydb_ai_nl.create_value_index(nl_config_id_in => 'property_search_config');
SELECT alloydb_ai_nl.refresh_value_index(nl_config_id_in => 'property_search_config');


-- 3. QUERY TEMPLATES (The "Master" Logic)
-- ===================================================================================

-- Template A: Simple Semantic Search
-- Intent: User asks for a "kind" of property without specific filters.
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Find properties like "a quiet place to study"',
  sql => $$
    SELECT id, title, description, bedrooms, price, city
    FROM search.property_listings
    ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'a quiet place to study')::vector
    LIMIT 5
  $$,
  check_intent => TRUE
);

-- Template B: Hybrid Query (Filters + Vector)
-- Intent: User combines hard filters (City, Price, Room count) with semantic descriptions.
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'min 3 rooms close to water not more than 6k',
  sql => $$
    SELECT image_gcs_uri, id, title, description, bedrooms, price, city
    FROM search.property_listings
    -- LOGIC: Extract hard numbers into WHERE, put "vibe" into Vector Order
    WHERE bedrooms >= 3 
      AND price <= 6000
    ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'close to water')::vector
    LIMIT 10
  $$,
  check_intent => TRUE
);

-- Template C: Specific Attribute Search
-- Intent: User asks for exact matches (e.g., specific bedroom counts in a city).
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Are there any 3-bedroom places in Geneva?',
  sql => $$
    SELECT id, title, description,bedrooms, price, city
    FROM search.property_listings
    WHERE bedrooms = 3 AND city = 'Geneva'
  $$,
  check_intent => TRUE
);

-- Template D: Parameterized Query
-- Intent: Explicitly teaches the AI to treat City as a variable ($1) for sorting logic.
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Show me the cheapest apartments in Geneva',
  sql => $$
    SELECT id, title, description, price, city
    FROM search.property_listings
    WHERE city = 'Geneva'
    ORDER BY price ASC
    LIMIT 10
  $$,
  parameterized_intent => 'Show me the cheapest apartments in $1',
  parameterized_sql => $$
    SELECT id, title, description, price, city
    FROM search.property_listings
    WHERE city = $1
    ORDER BY price ASC
    LIMIT 10
  $$,
  check_intent => TRUE
);

/* -- Template E: Visual / Aesthetic Search (Multimodal)
-- NOTE: Ensure 'image_embedding' column exists and 'multimodalembedding' model is registered.
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Find properties that look like "modern minimalist architecture"',
  sql => $$
    SELECT id, title, description, price, city, image_gcs_uri
    FROM search.property_listings
    ORDER BY image_embedding <=> embedding('multimodalembedding', 'modern minimalist architecture')::vector
    LIMIT 5
  $$,
  check_intent => TRUE
);
*/


-- 4. BUSINESS LOGIC FRAGMENTS (Handling Adjectives & Negation)
-- ===================================================================================

-- [Fragment] Negation handling
-- Solves: "Not ground floor" (Vector search struggles with 'NOT')
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'not ground floor',
  fragment => $$ (description NOT ILIKE '%ground floor%' AND description NOT ILIKE '%parterre%') $$
);

-- [Fragment] Ambiguity handling for "New"
-- Solves: Prevents "New" from matching "New roof" on an old house.
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'new',
  fragment => $$ (description ILIKE '%newly built%' OR description ILIKE '%first occupation%' OR description ILIKE '%modern%') $$
);

-- [Fragment] "Luxury" Definition
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'luxury',
  fragment => 'price >= 8000'
);

-- [Fragment] "Cheap/Budget" Definition
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'cheap',
  fragment => 'price <= 2500'
);

-- [Fragment] "Family Friendly" Definition
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'family',
  fragment => 'bedrooms >= 3'
);

-- [Fragment] "Studio" Definition
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'studio',
  fragment => 'bedrooms = 0'
);

-- [Fragment] "Outdoor Space" Definition
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'outdoor space',
  fragment => $$ (description ILIKE '%garden%' OR description ILIKE '%terrace%' OR description ILIKE '%balcony%') $$
);


-- 5. VERIFICATION
-- ===================================================================================
SELECT template_id, intent, sql FROM alloydb_ai_nl.template_store_view WHERE config = 'property_search_config';
SELECT intent, fragment FROM alloydb_ai_nl.fragment_store_view WHERE config = 'property_search_config';

-- Test Query
SELECT alloydb_ai_nl.get_sql(
  'property_search_config',
  'Show me cheap family apartments in Zurich not ground floor'
) ->> 'sql';