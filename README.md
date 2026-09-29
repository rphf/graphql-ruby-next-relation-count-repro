# Execution::Next: extra `COUNT(*)` for relation lists

With `execute_next`, a list field that returns an unloaded ActiveRecord relation runs a `SELECT COUNT(*)` before it loads the records. `execute` only loads the records.

```sh
ruby repro.rb
```

You only need Ruby. The script installs its gems with `bundler/inline` and uses an in-memory SQLite database. To try a local checkout of graphql-ruby, run `GRAPHQL_PATH=/path/to/graphql-ruby ruby repro.rb`.

Output with graphql 2.6.11 and activerecord 8.1.4:

```
execute: 4 queries
  SELECT "authors".* FROM "authors"
  SELECT "posts".* FROM "posts" WHERE "posts"."author_id" = ?
  SELECT "posts".* FROM "posts" WHERE "posts"."author_id" = ?
  SELECT "posts".* FROM "posts" WHERE "posts"."author_id" = ?

execute_next: 8 queries
  SELECT COUNT(*) FROM "authors"
  SELECT "authors".* FROM "authors"
  SELECT COUNT(*) FROM "posts" WHERE "posts"."author_id" = ?
  SELECT "posts".* FROM "posts" WHERE "posts"."author_id" = ?
  SELECT COUNT(*) FROM "posts" WHERE "posts"."author_id" = ?
  SELECT "posts".* FROM "posts" WHERE "posts"."author_id" = ?
  SELECT COUNT(*) FROM "posts" WHERE "posts"."author_id" = ?
  SELECT "posts".* FROM "posts" WHERE "posts"."author_id" = ?

execute_next ran 4 more queries than execute.
```
