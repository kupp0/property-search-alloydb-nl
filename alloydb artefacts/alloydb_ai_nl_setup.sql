SET search_path TO "search", public;

-- Install the Natural Language extension
DROP EXTENSION alloydb_ai_nl CASCADE;
CREATE EXTENSION IF NOT EXISTS alloydb_ai_nl CASCADE;

-- Verify installation
SELECT * FROM pg_available_extensions WHERE name = 'alloydb_ai_nl';
ALTER EXTENSION alloydb_ai_nl UPDATE; -- Ensure latest version

-- CERATE NL Config
SELECT alloydb_ai_nl.g_create_configuration(
  'property_search_config'  -- configuration_id
);


/*
STEP 4: Register Schema Objects
Tell the NL feature which tables/views to consider.
*/


SELECT alloydb_ai_nl.g_manage_configuration(
  operation        => 'register_table_view',
  configuration_id_in => 'property_search_config',
  table_views_in    => ARRAY['search.property_listings']
);

/*
STEP 5: Generate and Apply Schema Context
This step analyzes your table structure and data to generate descriptions for tables and columns, which helps the LLM understand your data.
*/

-- Generate context
SELECT alloydb_ai_nl.generate_schema_context(
  'property_search_config',
  TRUE -- Overwrite existing generated context in the view
);

-- Review the generated context (Optional)
SELECT schema_object, object_context
FROM alloydb_ai_nl.generated_schema_context_view;

-- Example: Update context if needed (e.g., for clarity)
-- SELECT alloydb_ai_nl.update_generated_relation_context(
--   'search.property_listings',
--   'This table contains property listings for rent or sale.'
-- );
-- SELECT alloydb_ai_nl.update_generated_column_context(
--   'search.property_listings.bedrooms',
--   'The number of bedrooms in the property. 0 indicates a studio apartment.'
-- );

-- Apply the context to the database objects as comments
SELECT alloydb_ai_nl.apply_generated_schema_context('property_search_config');

/*
STEP 6: Define Concept Types and Value Indexes
This helps the NL engine map words/phrases in the question to specific values in your database columns.
*/
-- Associate the 'city' column with the built-in 'city_name' concept type
SELECT alloydb_ai_nl.associate_concept_type(
  column_names_in => 'search.property_listings.city',
  concept_type_in => 'city_name',
  nl_config_id_in => 'property_search_config'
);


---Generate associations for all relations within the scope:
SELECT alloydb_ai_nl.generate_concept_type_associations('property_search_config');
--review
SELECT * from alloydb_ai_nl.generated_value_index_columns_view;


--Verify existing concept types
SELECT alloydb_ai_nl.list_concept_types();


-- You could define custom concept types if needed, but let's use built-ins for now.
-- ......

-- apply all concept types to the config
SELECT alloydb_ai_nl.apply_generated_concept_type_associations('property_search_config');

-- Create the value index based on the associated concept types
SELECT alloydb_ai_nl.create_value_index(nl_config_id_in => 'property_search_config');
SELECT alloydb_ai_nl.refresh_value_index(nl_config_id_in => 'property_search_config');



/*
STEP 7: Add Query Templates
Provide examples of natural language questions and their corresponding SQL. This is crucial for accuracy, especially for hybrid search.
*/

-- 0 List all query templates:
SELECT nl, sql, intent, psql, pintent
FROM alloydb_ai_nl.template_store_view
WHERE config = 'property_search_config';


-- Template 1: Simple semantic search
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Find properties like "a quiet place to study"',
  sql => $$
    SELECT id, title, description, price, city
    FROM search.property_listings
    ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'a quiet place to study')::vector
    LIMIT 5
  $$,
  check_intent => TRUE
);

-- Template 2: Hybrid search with filters
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Show me modern apartments in Zurich under 5000',
  sql => $$
    SELECT id, title, description, price, city
    FROM search.property_listings
    WHERE city = 'Zurich' AND price < 5000
    ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'modern apartment')::vector
    LIMIT 5
  $$,
  check_intent => TRUE
);

-- Template 3: Search by number of bedrooms and city
SELECT alloydb_ai_nl.add_template(
  nl_config_id => 'property_search_config',
  intent => 'Are there any 3-bedroom places in Geneva?',
  sql => $$
    SELECT id, title, description, price, city
    FROM search.property_listings
    WHERE bedrooms = 3 AND city = 'Geneva'
  $$,
  check_intent => TRUE
);

-- Template 4: Parameterized semantic search
SELECT alloydb_ai_nl.add_template(
    nl_config_id => 'property_search_config',
    intent => 'Find places similar to: peaceful home with garden',
    sql => $$
        SELECT id, title, description, price, city
        FROM search.property_listings
        ORDER BY description_embedding <=> embedding('gemini-embedding-001', 'peaceful home with garden')::vector
        LIMIT 5
    $$,
    parameterized_intent => 'Find places similar to: $1',
    parameterized_sql => $$
        SELECT id, title, description, price, city
        FROM search.property_listings
        ORDER BY description_embedding <=> embedding('gemini-embedding-001', $1)::vector
        LIMIT 5
    $$,
    check_intent => TRUE
);


-- Not part Fragments to enrich busness context:
SELECT intent, fragment, pintent
FROM alloydb_ai_nl.fragment_store_view;



/*
STEP 8: Test Natural Language Queries
Now you can test the NL2SQL generation:
*/

-- Test 1: Generate SQL
SELECT alloydb_ai_nl.get_sql(
  'property_search_config',
  'I need a 2-bedroom flat in Geneva under 4000'
) ->> 'sql';

SELECT "id", "title", "description", "price", "city" FROM "search"."property_listings" WHERE "bedrooms" = 2 AND "city" = 'Geneva' AND "price" < 4000

-- test result: 
SELECT "id", "title", "description", "price", "city" FROM "search"."property_listings" WHERE "bedrooms" = 2 AND "city" = 'Geneva' AND "price" < 4000


-- Test 2: Generate SQL for semantic search
SELECT alloydb_ai_nl.get_sql(
  'property_search_config',
  'Show me listings good for a family near Basel'
) ->> 'sql';
-- test result:
-- NOTE: Assuming "good for a family" refers to properties with a description similar to "family-friendly". 
SELECT "id", "title", "description", "price", "city" FROM "search"."property_listings" WHERE "city" = 'Basel' ORDER BY "description_embedding" <=> embedding('gemini-embedding-001', 'family-friendly')::vector LIMIT 5

SELECT "id", "title", "description", "price", "city" FROM "search"."property_listings" WHERE "city" = 'Basel' ORDER BY "description_embedding" <=> embedding('gemini-embedding-001', 'family friendly')::vector LIMIT 5

-- Test 3: Get a Natural Language Summary
SELECT alloydb_ai_nl.get_sql_summary(
  nl_config_id => 'property_search_config',
  nl_question => 'How many listings are in Zurich?'
);

-- Test 4: Using a parameterized template
SELECT alloydb_ai_nl.get_sql(
  'property_search_config',
  'Find places similar to: luxury penthouse and cheaper than 4000 CHF'
) ->> 'sql';

--test result:
SELECT "id", "title", "description", "price", "city" FROM "search"."property_listings" WHERE "price" < 4000 ORDER BY "description_embedding" <=> embedding('gemini-embedding-001', 'luxury penthouse')::vector LIMIT 5

