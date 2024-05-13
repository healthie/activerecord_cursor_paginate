## master (unreleased)

- Fix iterating using only a timestamp column

- Add the ability to skip implicitly appending a primary key to the list of sorting columns.

    It may be useful to disable it for the table with a UUID primary key or when the sorting
    is done by a combination of columns that are already unique.

    ```ruby
    paginator = UserSettings.cursor_paginate(order: :user_id, append_primary_key: false)
    ```

## 0.1.0 (2024-03-08)

- First release
