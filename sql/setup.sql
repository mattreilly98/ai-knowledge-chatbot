-- AI Knowledge Chatbot: database setup for Supabase (Postgres + pgvector)
-- Run this once in the Supabase SQL Editor on a NEW project.
-- It was written from my own build. I have not run it as a single script on a fresh project.
-- Do not run it on a database that already has a document_chunks table.

-- 1. Turn on the vector extension (lets Postgres store and compare embeddings)
create extension if not exists vector with schema extensions;

-- 2. The table that stores each piece of text, its details and its embedding
create table document_chunks (
  id bigserial primary key,
  content text,                 -- the piece of text
  metadata jsonb,               -- details such as the line range it came from
  embedding vector(1536)        -- 1536 = size of OpenAI text-embedding-3-small
);

-- 3. The search function the n8n Supabase Vector Store node calls.
--    It returns the stored pieces closest in meaning to the question.
create or replace function match_documents (
  query_embedding vector(1536),
  match_count int default 5,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    document_chunks.id,
    document_chunks.content,
    document_chunks.metadata,
    1 - (document_chunks.embedding <=> query_embedding) as similarity
  from document_chunks
  where document_chunks.metadata @> filter
  order by document_chunks.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- 4. Block access with the public key. The n8n workflows connect with the secret key,
--    which is not affected by this setting.
alter table document_chunks enable row level security;

-- 5. Optional, for a much larger knowledge base: add a search index.
--    Not needed at around 50 rows, so it is commented out.
-- create index on document_chunks using hnsw (embedding vector_cosine_ops);
