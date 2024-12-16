## master (unreleased)

- Fix paginating over relations with joins, includes and custom ordering
- Add ability to incrementally configure a paginator

- Add ability to get the total number of records

    ```ruby
    paginator = posts.cursor_paginate
    paginator.total_count # => 145
    ```

## 0.2.0 (2024-05-23)

- Fix prefixing selected columns when iterating over joined tables
- Change cursor encoding to url safe base64
- Fix `next_cursor`/`previous_cursor` for empty pages
- Fix iterating using only a timestamp column

- Add the ability to skip implicitly appending a primary key to the list of sorting columns.

    It may be useful to disable it for the table with a UUID primary key or when the sorting
    is done by a combination of columns that are already unique.

    ```ruby
    paginator = UserSettings.cursor_paginate(order: :user_id, append_primary_key: false)
    ```

## 0.1.0 (2024-03-08)

- First release
