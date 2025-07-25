{
  buildPgrxExtension,
  cargo-pgrx_0_12_6,
  postgresql,
  fetchFromGitHub,
  lib,
  postgresqlTestExtension,
}:

buildPgrxExtension (finalAttrs: {
  pname = "pgvectorscale";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "timescale";
    repo = "pgvectorscale";
    tag = finalAttrs.version;
    hash = "sha256-dy481k2SvyYXwwcsyLZSl3XlhSk9C5+4LfEfciB1DK4=";
  };

  doCheck = false;

  cargoHash = "sha256-CeRyDn9VhxfjWFJ1/Z/XvOUQOSnDoHHZAqgfYTeKU0o=";
  cargoPatches = [
    ./add-Cargo.lock.patch
  ];

  cargoPgrxFlags = [
    "-p"
    "vectorscale"
  ];

  inherit postgresql;
  cargo-pgrx = cargo-pgrx_0_12_6;

  passthru.tests.extension = postgresqlTestExtension {
    inherit (finalAttrs) finalPackage;
    withPackages = [ "pgvector" ];
    sql = ''
      CREATE EXTENSION vectorscale CASCADE;
      CREATE TABLE document_embedding  (
          id BIGINT PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
          embedding VECTOR(3)
      );

      INSERT INTO document_embedding (id, embedding) VALUES
      (10, '[1,2,4]'),
      (20, '[1,2,5]');

      CREATE INDEX document_embedding_idx ON document_embedding
      USING diskann (embedding vector_cosine_ops);
    '';
    asserts = [
      {
        query = "SELECT id FROM document_embedding WHERE embedding <-> '[1,2,3]' = 1";
        expected = "10";
        description = "Expected vector of row with ID=10 to have an euclidean distance from [1,2,3] of 1.";
      }
      {
        query = "SELECT id FROM document_embedding WHERE embedding <-> '[1,2,3]' = 2";
        expected = "20";
        description = "Expected vector of row with ID=20 to have an euclidean distance from [1,2,3] of 2.";
      }
    ];
  };

  meta = {
    homepage = "https://github.com/timescale/pgvectorscale";
    teams = [ lib.teams.flyingcircus ];
    description = "Complement to pgvector for high performance, cost efficient vector search on large workloads";
    license = lib.licenses.postgresql;
    platforms = postgresql.meta.platforms;
    changelog = "https://github.com/timescale/pgvectorscale/releases/tag/${finalAttrs.version}";
  };
})
