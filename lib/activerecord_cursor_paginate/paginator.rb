# frozen_string_literal: true

module ActiveRecordCursorPaginate
  # Use this Paginator class to effortlessly paginate through ActiveRecord
  # relations using cursor pagination.
  #
  # @example Iterating one page at a time
  #     ActiveRecordCursorPaginate::Paginator
  #       .new(relation, order: :author, limit: 2, after: "WyJKYW5lIiw0XQ==")
  #       .fetch
  #
  # @example Iterating over the whole relation
  #     paginator = ActiveRecordCursorPaginate::Paginator
  #                   .new(relation, order: :author, limit: 2, after: "WyJKYW5lIiw0XQ==")
  #
  #     # Will lazily iterate over the pages.
  #     paginator.pages.each do |page|
  #       # do something with the page
  #     end
  #
  class Paginator
    # Create a new instance of the `ActiveRecordCursorPaginate::Paginator`
    #
    # @param relation [ActiveRecord::Relation] Relation that will be paginated.
    # @param before [String, nil] Cursor to paginate upto (excluding).
    # @param after [String, nil] Cursor to paginate forward from.
    # @param limit [Integer, nil] Number of records to return in pagination.
    # @param order [Symbol, String, nil, Array<Symbol, String>, Hash]
    #   Column(s) to order by, optionally with directions (either `:asc` or `:desc`,
    #   defaults to `:asc`). If none is provided, will default to ID column.
    #   NOTE: this will cause the query to filter on both the given column as
    #   well as the ID column. So you might want to add a compound index to your
    #   database similar to:
    #   ```sql
    #     CREATE INDEX <index_name> ON <table_name> (<order_fields>..., id)
    #   ```
    # @raise [ArgumentError] If any parameter is not valid
    #
    def initialize(relation, before: nil, after: nil, limit: nil, order: nil)
      unless relation.is_a?(ActiveRecord::Relation)
        raise ArgumentError, "relation is not an ActiveRecord::Relation"
      end

      if before.present? && after.present?
        raise ArgumentError, "Only one of :before and :after can be provided"
      end

      @relation = relation
      @primary_key = @relation.primary_key
      @cursor = before || after
      @is_forward_pagination = before.blank?

      config = ActiveRecordCursorPaginate.config
      @page_size = limit || config.default_page_size
      @page_size = [@page_size, config.max_page_size].min if config.max_page_size

      order = normalize_order(order)
      @columns = order.keys
      @directions = order.values
    end

    # Get the paginated result.
    # @return [ActiveRecordCursorPaginate::Page]
    #
    # @note Calling this method advances the paginator.
    #
    def fetch
      relation = @relation

      # Non trivial columns (expressions or joined tables columns).
      if @columns.any?(/\W/)
        arel_columns = @columns.map.with_index do |column, i|
          arel_column(column).as("cursor_column_#{i + 1}")
        end
        cursor_column_names = 1.upto(@columns.size).map { |i| "cursor_column_#{i}" }

        relation =
          if relation.select_values.empty?
            relation.select(Arel.star, arel_columns)
          else
            relation.select(arel_columns)
          end
      else
        cursor_column_names = @columns
      end

      pagination_directions = @directions.map { |direction| pagination_direction(direction) }
      relation = relation.reorder(cursor_column_names.zip(pagination_directions).to_h)

      if @cursor
        decoded_cursor = Cursor.decode(cursor_string: @cursor, columns: @columns)
        relation = apply_cursor(relation, decoded_cursor)
      end

      relation = relation.limit(@page_size + 1)
      records_plus_one = relation.to_a
      has_additional = records_plus_one.size > @page_size

      records = records_plus_one.take(@page_size)
      records.reverse! unless @is_forward_pagination

      if @is_forward_pagination
        has_next_page = has_additional
        has_previous_page = @cursor.present?
      else
        has_next_page = @cursor.present?
        has_previous_page = has_additional
      end

      page = Page.new(
        records,
        order_columns: cursor_column_names,
        has_next: has_next_page,
        has_previous: has_previous_page
      )

      advance_by_page(page) unless page.empty?

      page
    end
    alias page fetch

    # Returns an enumerator that can be used to iterate over the whole relation.
    # @return [Enumerator]
    #
    def pages
      Enumerator.new do |yielder|
        loop do
          page = fetch
          break if page.empty?

          yielder.yield(page)
        end
      end
    end

    private
      def normalize_order(order)
        order ||= {}
        default_direction = :asc

        result =
          case order
          when String, Symbol
            { order => default_direction }
          when Hash
            order
          when Array
            order.to_h { |column| [column, default_direction] }
          else
            raise ArgumentError, "Invalid order: #{order.inspect}"
          end

        result = result.with_indifferent_access
        result.transform_values! { |direction| direction.downcase.to_sym }
        Array(@primary_key).each { |column| result[column] ||= default_direction }
        result
      end

      def apply_cursor(relation, cursor)
        operators = @directions.map { |direction| pagination_operator(direction) }
        cursor_positions = cursor.columns.zip(cursor.values, operators)

        where_clause = nil
        cursor_positions.reverse_each.with_index do |(column, value, operator), index|
          where_clause =
            if index == 0
              arel_column(column).public_send(operator, value)
            else
              arel_column(column).public_send(operator, value).or(
                arel_column(column).eq(value).and(where_clause)
              )
            end
        end

        relation.where(where_clause)
      end

      def arel_column(column)
        if Arel.arel_node?(column)
          column
        elsif column.match?(/\A\w+\.\w+\z/)
          Arel.sql(column)
        else
          @relation.arel_table[column]
        end
      end

      def pagination_direction(direction)
        if @is_forward_pagination
          direction
        else
          direction == :asc ? :desc : :asc
        end
      end

      def pagination_operator(direction)
        if @is_forward_pagination
          direction == :asc ? :gt : :lt
        else
          direction == :asc ? :lt : :gt
        end
      end

      def advance_by_page(page)
        @cursor =
          if @is_forward_pagination
            page.next_cursor
          else
            page.previous_cursor
          end
      end
  end
end
