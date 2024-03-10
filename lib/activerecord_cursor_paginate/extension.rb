# frozen_string_literal: true

module ActiveRecordCursorPaginate
  module Extension
    # Convenient method to use on ActiveRecord::Relation to get a paginator.
    # @return [ActiveRecordCursorPaginate::Paginator]
    # @see ActiveRecordCursorPaginate::Paginator#initialize
    #
    # @example
    #   paginator = Post.cursor_paginate(limit: 2, after: "Mg==")
    #   page = paginator.fetch
    #
    def cursor_paginate(after: nil, before: nil, limit: nil, order: nil, append_primary_key: true)
      relation = (is_a?(ActiveRecord::Relation) ? self : all)
      Paginator.new(relation, after: after, before: before, limit: limit, order: order, append_primary_key: append_primary_key)
    end
    alias cursor_pagination cursor_paginate
  end
end
