/*
===================================================================================
ALLOYDB AI NATURAL LANGUAGE CONFIGURATION GUIDE
===================================================================================

This configuration defines how the LLM translates natural language into SQL.
It relies on three distinct layers working together: Templates, Concept Types, and Fragments.

1. QUERY TEMPLATES (The "Skeleton" / Grammar)
   --------------------------------------------------------------------------------
   * What they do: Define the overall SQL structure (SELECT, FROM, ORDER BY).
   * Use them for: Defining distinct user *Intents* or actions.
   * Example: "Find properties like X" (Semantic Search) vs "Count the apartments" (Aggregation).
   * Best Practice:
     - You DO NOT need a template for every value (e.g., one for Zurich, one for Bern).
     - Provide one robust example (e.g., using 'Geneva') and the AI will generalize the pattern.
     - Use parameterized templates ($1) only for complex logic where simple pattern matching fails.

2. CONCEPT TYPES (The "Vocabulary" / Nouns)
   --------------------------------------------------------------------------------
   * What they do: Map real-world entities to specific database columns.
   * Use them for: Helping the AI recognize that "Zurich" is a City and "Google" is a Company.
   * Built-ins: 'city_name', 'company_name', etc., are available out of the box.
   * Custom: You can define custom maps (e.g., mapping "The Big Apple" -> 'New York').

3. FRAGMENTS (The "Business Rules" / Adjectives)
   --------------------------------------------------------------------------------
   * What they do: Reusable SQL snippets injected into the WHERE clause.
   * Use them for: "Soft filters" or specific business jargon that implies hard numbers.
   * Example:
     - User says "Luxury" -> Fragment injects "price > 6000"
     - User says "Studio" -> Fragment injects "bedrooms = 0"
   * Why crucial: Without fragments, the AI might just search for the word "Luxury"
     in the description text instead of applying a hard price filter.

===================================================================================
CHEAT SHEET: WHEN TO USE WHAT?
===================================================================================
* If you need to change WHAT data is returned (columns/aggregates) -> Use a TEMPLATE.
* If you need to teach the AI a specific Value (Location, Name)    -> Use a CONCEPT TYPE.
* If you need to enforce a Rule based on a keyword (Cheap, Big)    -> Use a FRAGMENT.
===================================================================================
*/

-- 0. SETUP & INITIALIZATION
-- ===================================================================================
SET search_path TO "search", public;

-- Install the Natural Language extension
DROP EXTENSION IF EXISTS alloydb_ai_nl CASCADE;
CREATE EXTENSION IF NOT EXISTS alloydb_ai_nl CASCADE;

-- Verify installation and ensure latest version
SELECT * FROM pg_available_extensions WHERE name = 'alloydb_ai_nl';
ALTER EXTENSION alloydb_ai_nl UPDATE;

-- 1. CREATE CONFIGURATION & CONTEXT
-- ===================================================================================

-- Create the configuration holder
SELECT alloydb_ai_nl.g_create_configuration(
  'property_search_config'
);

-- Register Schema Objects
-- Tell the NL feature which tables/views to consider.
SELECT alloydb_ai_nl.g_manage_configuration(
  operation        => 'register_table_view',
  configuration_id_in => 'property_search_config',
  table_views_in    => ARRAY['search.property_listings']
);

-- Generate Schema Context
-- Analyzes table structure to help the LLM understand the data.
SELECT alloydb_ai_nl.generate_schema_context(
  'property_search_config',
  TRUE -- Overwrite existing generated context in the view
);

-- Optional: Review the generated context
SELECT schema_object, object_context FROM alloydb_ai_nl.generated_schema_context_view;

-- Apply the context to the database objects as comments
SELECT alloydb_ai_nl.apply_generated_schema_context('property_search_config');



-- 2. CONCEPT TYPES
-- ===================================================================================
-- Associate the 'city' column with the built-in 'city_name' concept type
SELECT alloydb_ai_nl.associate_concept_type(
  column_names_in => 'search.property_listings.city',
  concept_type_in => 'city_name',
  nl_config_id_in => 'property_search_config'
);
-- 1. Update the context to explicitly warn about Case Sensitivity
SELECT alloydb_ai_nl.update_generated_column_context(
  'search.property_listings.city',
  -- We tell the AI two things:
  -- 1. The format (Title Case)
  -- 2. The preferred operator (ILIKE) to be safe
  'The city name stored in Title Case (e.g. Zurich, Geneva). When filtering by city, convert the input to Title Case or use the ILIKE operator to ignore case.'
);
-- 2. Apply this new context to the active configuration
SELECT alloydb_ai_nl.apply_generated_schema_context('property_search_config');

-- Generate associations and apply them
SELECT alloydb_ai_nl.generate_concept_type_associations('property_search_config');
SELECT alloydb_ai_nl.apply_generated_concept_type_associations('property_search_config');

-- Create and refresh the value index (critical for looking up specific values like "Zurich")
SELECT alloydb_ai_nl.create_value_index(nl_config_id_in => 'property_search_config');
SELECT alloydb_ai_nl.refresh_value_index(nl_config_id_in => 'property_search_config');


-- 3. QUERY TEMPLATES
-- ===================================================================================

-- Template 1: Simple Semantic Search
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

/*
-- Template 2: Hybrid Search with Filters
-- Intent: User combines filters (City, Price) with semantic description.
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Show me modern apartments in Zurich under 5000',
  sql => $$
    SELECT id, title, description,bedrooms, price, city
    FROM search.property_listings
    WHERE city = 'Zurich' AND price < 5000
    ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'modern apartment')::vector
    LIMIT 5
  $$,
  check_intent => TRUE
);
*/

-- 1. First, ensure we clean up any conflicting "exact match" templates if they exist
-- (Optional, but good practice if you have old junk templates)
-- SELECT alloydb_ai_nl.drop_template(nl_config_id => 'property_search_config', template_id => 'YOUR_OLD_ID');

-- 2. Add the Hybrid Template
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  -- The example intent mirrors your complex query structure
  intent => 'min 3 rooms close to water not more than 6k',
  sql => $$
    SELECT image_gcs_uri, id, title, description, bedrooms, price, city
    FROM search.property_listings
    -- LOGIC A: Extract the hard numbers into the WHERE clause
    WHERE bedrooms >= 3 
      AND price <= 6000
    -- LOGIC B: Put the "vibe" or description into the vector search
    -- The embedding model will automatically correct "watr" to "water" contextually
    ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'close to water')::vector
    LIMIT 10
  $$,
  check_intent => TRUE
);

-- Template 3: Specific Attribute Search
-- Intent: User asks for exact bedroom counts in a city.
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

-- Template 4: Parameterized Query (Robust Logic)
-- Intent: Explicitly teaches the AI to treat City as a variable ($1).
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Show me the cheapest apartments in Geneva',
  -- NOTE: The 'sql' field must be a valid, executable query matching the 'intent' example.
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

-- Template 5: Visual / Aesthetic Search
-- Intent: Search using the multimodal image embedding space.
/* !!!!!!!!!!!!!!!!!!!!!!!!!!!! Error: NEED TO BE FIXED !!!!!!!!!!!!!!!!!!!!!!!!!!!!
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


-- 4. BUSINESS LOGIC FRAGMENTS
-- ===================================================================================
-- Registers reusable "soft filters" (Adjectives) to the configuration.

-- 1. Luxury Fragment 
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'], -- Specifies the table scope
  intent => 'luxury',
  fragment => 'price >= 8000'
);

-- 2. Budget/Cheap Fragment 
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'cheap',
  fragment => 'price <= 2500'
);

-- 3. Family Friendly Fragment 
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'family',
  fragment => 'bedrooms >= 3'
);

-- 4. Studio Fragment 
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'studio',
  fragment => 'bedrooms = 0'
);

-- 5. Outdoor Space Fragment 
SELECT alloydb_ai_nl.add_fragment(
  nl_config_id => 'property_search_config',
  table_aliases => ARRAY['search.property_listings'],
  intent => 'outdoor space',
  -- USAGE FIX: Used $$ (Dollar Quotes) to treat this as a string literal, not a column name
  fragment => $$ (description ILIKE '%garden%' OR description ILIKE '%terrace%' OR description ILIKE '%balcony%') $$
);

SELECT intent, fragment 
FROM alloydb_ai_nl.fragment_store_view 
WHERE config = 'property_search_config';

-- 5. VERIFICATION & TESTING
-- ===================================================================================
/*
-- List all templates
SELECT nl, sql, intent FROM alloydb_ai_nl.template_store_view WHERE config = 'property_search_config';

-- List all fragments
SELECT intent, fragment FROM alloydb_ai_nl.fragment_store_view WHERE config = 'property_search_config';
*/

-- Test 1: Simple Logic (Should use Template 3 or generate WHERE clauses)
SELECT alloydb_ai_nl.get_sql(
  'property_search_config',
  'I need a 2-bedroom flat in Geneva under 4000'
) ->> 'sql';

-- Test 2: Business Logic (Should use "Family" fragment)
SELECT alloydb_ai_nl.get_sql(
  'property_search_config',
  'Show me listings good for a family '
) ->> 'sql';
