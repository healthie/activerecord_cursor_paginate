# frozen_string_literal: true

require "test_helper"

class PaginatorTest < Minitest::Test
  def test_raises_when_non_relation
    error = assert_raises(ArgumentError) do
      ActiveRecordCursorPaginate::Paginator.new("non_relation")
    end
    assert_equal("relation is not an ActiveRecord::Relation", error.message)
  end

  def test_raises_when_before_and_after_present
    error = assert_raises(ArgumentError) do
      User.cursor_paginate(before: 1, after: 2)
    end
    assert_equal("Only one of :before and :after can be provided", error.message)
  end

  def test_raises_when_no_primary_key_and_order_is_empty
    error = assert_raises(ArgumentError) do
      NoPkTable.cursor_paginate
    end
    assert_equal(":order must contain columns to order by", error.message)
  end

  def test_paginates_by_id_by_default
    p = User.cursor_paginate
    users = p.fetch.records
    assert_equal((1..10).to_a, users.pluck(:id))
  end

  def test_paginates_by_id_with_custom_conditions
    p = User.where("id > 3 AND id < 10").cursor_paginate
    users = p.fetch.records
    assert_equal((4..9).to_a, users.pluck(:id))
  end

  def test_uses_default_limit
    ActiveRecordCursorPaginate.config.stub(:default_page_size, 4) do
      p = User.cursor_paginate
      users = p.fetch.records
      assert_equal([1, 2, 3, 4], users.pluck(:id))
    end
  end

  def test_custom_limit
    p = User.cursor_paginate(limit: 3)
    users = p.fetch.records
    assert_equal([1, 2, 3], users.pluck(:id))
  end

  def test_uses_max_page_size
    ActiveRecordCursorPaginate.config.stub(:max_page_size, 5) do
      p = User.cursor_paginate(limit: 10)
      users = p.fetch.records
      assert_equal([1, 2, 3, 4, 5], users.pluck(:id))
    end
  end

  def test_paginates_by_id_desc
    p = User.cursor_paginate(order: { id: :desc })
    users = p.fetch.records
    assert_equal((1..10).to_a.reverse, users.pluck(:id))
  end

  def test_paginates_by_custom_column_and_direction
    p = User.cursor_paginate(order: { company_id: :asc })
    users = p.fetch.records
    assert_equal(User.order(:company_id, :id).pluck(:id, :company_id), users.pluck(:id, :company_id))
  end

  def test_order_by_id_without_direction
    p = User.cursor_paginate(order: :id)
    users = p.fetch.records
    assert_equal((1..10).to_a, users.pluck(:id))
  end

  def test_order_by_different_columns_without_directions
    p = User.cursor_paginate(limit: 4, order: [:company_id, :id])
    users = p.fetch.records
    assert_equal([[3, 1], [7, 1], [9, 1], [1, 2]], users.pluck(:id, :company_id))
  end

  def test_does_not_append_id_if_asked
    p = User.cursor_paginate(limit: 1, order: :company_id, append_primary_key: false)

    records = []
    p.pages.each do |page|
      records.concat(page.records)
    end
    assert_equal([1, 2, 3, 4], records.map(&:company_id))
  end

  def test_paginates_forward_after_cursor
    p1 = User.cursor_paginate(limit: 3)
    page1 = p1.fetch

    p2 = User.cursor_paginate(after: page1.cursor, limit: 4)
    page2 = p2.fetch
    assert_equal([4, 5, 6, 7], page2.records.pluck(:id))
  end

  def test_paginates_backward_before_cursor
    p1 = User.cursor_paginate(limit: 3, order: { id: :desc })
    p1.fetch
    page1 = p1.fetch

    p2 = User.cursor_paginate(before: page1.previous_cursor, order: { id: :desc })
    page2 = p2.fetch
    assert_equal([10, 9, 8], page2.records.pluck(:id))
  end

  def test_paginates_forward_after_cursor_and_custom_order
    p1 = User.cursor_paginate(limit: 2, order: { company_id: :asc, id: :desc })
    page1 = p1.fetch

    p2 = User.cursor_paginate(after: page1.cursor, limit: 4, order: { company_id: :asc, id: :desc })
    page2 = p2.fetch

    expected = [[3, 1], [6, 2], [1, 2], [8, 3]]
    assert_equal(expected, page2.records.pluck(:id, :company_id))
  end

  def test_paginates_backward_before_cursor_and_custom_order
    p1 = User.cursor_paginate(limit: 5, order: { company_id: :asc, id: :desc })
    p1.fetch
    page1 = p1.fetch

    p2 = User.cursor_paginate(before: page1.previous_cursor, limit: 3, order: { company_id: :asc, id: :desc })
    page2 = p2.fetch
    assert_equal([[3, 1], [6, 2], [1, 2]], page2.records.pluck(:id, :company_id))
  end

  def test_paginates_forward_after_latest_cursor
    p1 = User.cursor_paginate(limit: User.count)
    page1 = p1.fetch

    p2 = User.cursor_paginate(after: page1.cursor)
    page2 = p2.fetch
    assert_empty(page2.records)
  end

  def test_paginates_backward_before_latest_cursor
    p1 = User.cursor_paginate
    page1 = p1.fetch

    p2 = User.cursor_paginate(before: page1.previous_cursor)
    page2 = p2.fetch
    assert_empty(page2.records)
  end

  def test_raises_for_invalid_cursor
    p = User.cursor_paginate(after: "invalid")
    error = assert_raises(ActiveRecordCursorPaginate::InvalidCursorError) do
      p.fetch
    end
    assert_equal("The given cursor `invalid` could not be decoded", error.message)
  end

  def test_raises_for_cursor_with_invalid_size
    user = User.first
    # Cursor is created for 2 columns, bu we order only by 1.
    cursor = ActiveRecordCursorPaginate::Cursor.from_record(user, columns: [:company_id, :id]).encode
    p = User.cursor_paginate(after: cursor, order: { id: :desc })
    error = assert_raises(ActiveRecordCursorPaginate::InvalidCursorError) do
      p.fetch
    end
    assert_equal("The given cursor `#{cursor}` was decoded as `[#{user.company_id}, #{user.id}]` but could not be parsed", error.message)
  end

  def test_paginating_over_empty_relation
    p = User.none.cursor_paginate
    page = p.fetch
    assert_empty(page.records)
  end

  def test_paginating_over_time_column
    p = User.cursor_paginate(limit: 3, order: { created_at: :asc })
    page1 = p.fetch
    assert_equal([5, 3, 8], page1.records.pluck(:id))

    page2 = p.fetch
    assert_equal([7, 4, 10], page2.records.pluck(:id))
  end

  def test_paginating_over_all_pages
    p = User.cursor_paginate(limit: 2)

    records = []
    p.pages.each do |page|
      assert_equal(2, page.count)
      records.concat(page.records)
    end

    assert_equal(User.order(:id).to_a, records)
  end

  def test_ordering_and_joins
    p = User.joins(:projects).select("users.*, projects.stars").cursor_paginate(limit: 3, order: [:id, "projects.stars"])
    page1 = p.fetch
    assert_equal([[1, 9], [1, 10], [2, 5]], page1.records.pluck(:id, :stars))

    page2 = p.fetch
    assert_equal([[2, 6], [3, 2]], page2.records.pluck(:id, :stars))
  end

  def test_ordering_by_expression
    p = User.cursor_paginate(limit: 2, order: Arel.sql("id + 1"))
    page1 = p.fetch
    assert_equal([1, 2], page1.records.pluck(:id))

    page2 = p.fetch
    assert_equal([3, 4], page2.records.pluck(:id))
  end

  def test_ordering_by_expression_and_existing_cursor
    p1 = User.cursor_paginate(limit: 2, order: Arel.sql("id + 1"))
    _first_page = p1.fetch
    second_page = p1.fetch

    p2 = User.cursor_paginate(limit: 2, before: second_page.cursor, order: Arel.sql("id + 1"))
    page = p2.fetch
    assert_equal([2, 3], page.records.pluck(:id))
  end

  def test_raises_when_order_column_is_not_selected
    p = User.select(:company_id).cursor_paginate
    error = assert_raises(ArgumentError) do
      p.fetch
    end
    assert_equal("Cursor values can not be nil", error.message)
  end

  def test_works_with_composite_primary_keys
    skip if ActiveRecord.gem_version < Gem::Version.new("7.1")

    p1 = CpkUser.cursor_paginate(limit: 2)
    page1 = p1.fetch
    assert_equal([[1, 3], [1, 7]], page1.records.pluck(:company_id, :id))

    page2 = p1.fetch
    assert_equal([[1, 9], [2, 1]], page2.records.pluck(:company_id, :id))

    p2 = CpkUser.cursor_paginate(limit: 2, after: page2.previous_cursor)
    page3 = p2.fetch
    assert_equal([[2, 1], [2, 6]], page3.records.pluck(:company_id, :id))
  end

  def test_returns_page_object
    user1, user2 = User.first(2)
    p = User.cursor_paginate(limit: 2)
    page1 = p.fetch

    assert_equal([user1, user2], page1.records)
    assert_equal(2, page1.count)
    assert page1.next_cursor
    assert page1.previous_cursor
    assert_not page1.has_previous?
    assert page1.has_next?
    assert_equal(page1.previous_cursor, page1.cursor_for(user1))
    assert_equal(page1.next_cursor, page1.cursor_for(user2))
    assert_not_empty page1.cursors

    page2 = p.fetch
    assert page2.has_next?
    assert page2.has_previous?
  end
end
