#import "_style.typ": *
#show: setup

#diagram(
  spacing: (40pt, 28pt),
  ..boxes,
  node((0, 1), name: <saved>, db-table("saved_movies", (
    ([user_id], [uuid], [PK, FK]),
    ([id], [integer], [PK]),
    ([title], [text], []),
    ([overview], [text], []),
    ([release_date], [text], []),
    ([poster_path], [text, null], []),
    ([vote_average], [double], []),
    ([genre_ids], [integer\[\]], []),
    ([saved_at], [timestamptz], []),
  ))),
  node((0.5, 0), name: <users>, db-table("auth.users", (
    ([id], [uuid], [PK]),
    ([email], [text], []),
    ([...], [], []),
  ), fill: outside)),
  node((1, 1), name: <requests>, db-table("ai_requests", (
    ([id], [bigint], [PK]),
    ([user_id], [uuid], [FK]),
    ([requested_at], [timestamptz], []),
  ))),
  ..one-to-many(<users>, <saved>),
  ..one-to-many(<users>, <requests>),
)
