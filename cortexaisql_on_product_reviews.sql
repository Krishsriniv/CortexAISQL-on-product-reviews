-- Executable SQL Examples for Cortex AISQL
-- Assumptions:
-- 1. You have a running warehouse selected
-- 2. Your role has access to Cortex functions

CREATE DATABASE CORTEX_AISQL_DEMO_DB;
USE DATABASE CORTEX_AISQL_DEMO_DB;

/* ============================================================
   Example 1: product reviews + concise summaries
   ============================================================ */

CREATE OR REPLACE TEMP TABLE PRODUCT_REVIEWS AS
SELECT * FROM VALUES
  (1, 'ZenTime Smart Z5',
     'This is Jim (j.jim@examplemail.com) I purchased the ZenTime Smart Z5 during a holiday sale after comparing it with three other smartwatches in the same price range. The initial setup was smooth, and the display quality exceeded my expectations. It is bright outdoors and the UI is fluid. I primarily use it for runs, sleep tracking, and managing work notifications. Battery life is consistently strong, lasting nearly four days with GPS enabled. However, the strap quality is disappointing; it started peeling after six weeks. Support responded quickly but refused a replacement citing cosmetic wear. Fitness metrics are mostly accurate for steady runs but inconsistent during intervals. Overall, it’s great for productivity and general fitness but not ideal for advanced athletes.'),

  (2, 'ZenTime Smart Z5',
     'I have used the ZenTime Smart Z5 for three months. Calling works well indoors, but wind noise affects clarity outdoors. Pairing works flawlessly with modern devices but is unreliable with older Android phones, causing delayed notifications. Sleep tracking insights are detailed but occasionally misclassify wake periods as deep sleep. The charger is the weakest part—it disconnects easily. Workout summaries sync quickly to the app, but exporting reports is harder than it should be. The watch is excellent for light to moderate fitness tracking and daily productivity, but serious athletes may feel limited.'),

  (3, 'ZenTime Fit Band',
     'The ZenTime Fit Band is extremely lightweight and comfortable for day-long wear. It is ideal for casual users who want step tracking, cycling logs, and light exercise insights. Battery life is great, even with continuous monitoring enabled. The app syncs fast and has a clean interface. It works well for casual health monitoring. A solid entry-level fitness band focused on comfort and battery life.')
AS PRODUCT_REVIEWS(PRODUCT_ID, PRODUCT_NAME, REVIEW_TEXT);

-- Summarize each product review concisely. Let's look at the first row
SELECT
  PRODUCT_ID,
  PRODUCT_NAME,
  AI_COMPLETE(
    'snowflake-arctic',
    'Summarize this review in about 30 words focusing on strengths, weaknesses, and overall sentiment: ' || REVIEW_TEXT
  ) AS REVIEW_SUMMARY
FROM PRODUCT_REVIEWS
LIMIT 1;


/* ============================================================
   Example 2: AI_SENTIMENT - Identify sentiment
   ============================================================ */

SELECT
  PRODUCT_ID,
  PRODUCT_NAME,
  AI_SENTIMENT(REVIEW_TEXT) AS SENTIMENT
FROM PRODUCT_REVIEWS;


/* ============================================================
   Example 3: AI_EXTRACT - Extract structured fields from text
   ============================================================ */

SELECT
  PRODUCT_ID,
  PRODUCT_NAME,
  AI_EXTRACT(
    text => REVIEW_TEXT,
    responseFormat => {
      'battery_life':      'What is said about battery life or how long it lasts?',
      'tracking_accuracy': 'What is said about fitness or tracking accuracy?',
      'strap_quality':     'What is said about the strap or band quality?',
      'usability':         'What is said about overall usability and day-to-day experience?'
    }
  ) AS EXTRACTED_ATTRIBUTES
FROM PRODUCT_REVIEWS;

/* ============================================================
   Example 4: AI_AGG - Aggregate themes across all reviews
   ============================================================ */

SELECT
  AI_AGG(
    REVIEW_TEXT,
    'Summarize major product themes including usability, performance issues, and feature gaps across all reviews in 5 sentences.'
  ) AS AGGREGATED_THEMES
FROM PRODUCT_REVIEWS;


/* ============================================================
   Example 5: AI_CLASSIFY - Categorize review focus areas
   ============================================================ */

SELECT
  PRODUCT_ID,
  AI_CLASSIFY(
    REVIEW_TEXT,
    ['Battery', 'Performance', 'Fitness Accuracy', 'Build Quality', 'Apps & Sync', 'Usability']
  ):labels AS PRIMARY_TOPICS
FROM PRODUCT_REVIEWS;

/* ============================================================
   Example 6: AI_TRANSLATE (Multilingual Insights)
   ============================================================ */
SELECT
    REVIEW_TEXT,
    AI_TRANSLATE(REVIEW_TEXT, '', 'es') AS SPANISH_TRANSLATED_REVIEW
FROM
    PRODUCT_REVIEWS;

/* ==============================================================
   Example 7: AI_SUMMARIZE_AGG – “Exec-level” rollup of all reviews
   ============================================================== */
SELECT
  AI_SUMMARIZE_AGG(REVIEW_TEXT) AS OVERALL_FEEDBACK_SUMMARY
FROM PRODUCT_REVIEWS;

/* ==================================================================================
   Example 8: AI_SIMILARITY – “How close is this review to a known complaint theme?
   ================================================================================== */
SELECT
 PRODUCT_ID,
 PRODUCT_NAME,
 REVIEW_TEXT,
 AI_SIMILARITY(
 REVIEW_TEXT,
 'Customer complains that the strap peels quickly and the charger disconnects easily.'
 ) AS SIMILARITY_TO_STRAP_AND_CHARGER_COMPLAINT
FROM PRODUCT_REVIEWS
ORDER BY SIMILARITY_TO_STRAP_AND_CHARGER_COMPLAINT DESC;

/* =================================================================
   Example 9: AI_EMBED_TEXT (Vector Embeddings for Search / RAG)
   ================================================================= */
-- Create embeddings for each review

CREATE OR REPLACE TEMP TABLE PRODUCT_REVIEW_EMBEDDINGS AS
SELECT
  PRODUCT_ID,
  PRODUCT_NAME,
  REVIEW_TEXT,
  AI_EMBED(
    'snowflake-arctic-embed-l-v2.0',   -- multilingual, 1024-dim model
    REVIEW_TEXT
  ) AS REVIEW_VECTOR
FROM PRODUCT_REVIEWS;

-- Perform semantic search on those embeddings

-- Example: finding reviews most similar to charger dock disconnects / strap issues

WITH QUERY_VEC AS (
  SELECT AI_EMBED(
    'snowflake-arctic-embed-l-v2.0',
    'Charging dock disconnects easily and the strap wore out quickly'
  ) AS QV
)
SELECT
  P.PRODUCT_ID,
  P.PRODUCT_NAME,
  P.REVIEW_TEXT,
  VECTOR_COSINE_SIMILARITY(P.REVIEW_VECTOR, Q.QV) AS SIMILARITY
FROM PRODUCT_REVIEW_EMBEDDINGS P,
     QUERY_VEC Q
ORDER BY SIMILARITY DESC;

/* ======================================================================
   Example 10: AI_REDACT (Mask Personally Identifiable Information - PII)
   ====================================================================== */

SELECT
  PRODUCT_ID,
  PRODUCT_NAME,
  REVIEW_TEXT,
  AI_REDACT(REVIEW_TEXT) AS REDACTED_REVIEW
FROM PRODUCT_REVIEWS
LIMIT 1;