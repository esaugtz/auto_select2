module Select2SearchAdapters
  class SearchAdapter
    class << self
      # Amount rows per ajax-request
      def limit
        25 # TODO: move to settings/config
      end

      def search_from_autocomplete(term, page, search_method, options)
        if search_method.nil?
          search_default(term, page, options)
        else
          self.send("search_#{search_method}", term, page, options)
        end
      end

    private

      def default_finder(searched_class, term, options)
        column = options[:column].present? ? options[:column] : 'name'
        conditions = default_search_conditions(term, options[:basic_conditions], column)
        if term.nil?
          [ searched_class.where(options[:basic_conditions]) ]
        else
          skip_count = 0
          unless options.nil? || options[:page].nil?
            page = options[:page].to_i > 0 ? options[:page].to_i : 1
            skip_count = limit * ( page - 1 )
          end
          query = searched_class.where( conditions ).limit( limit ).offset(skip_count).order(column)
          query = query.select(options[:select]) if options[:select].present?
          options[:uniq] ? query.uniq : query
        end
      end

      def default_count(searched_class, term, options = {})
        conditions = default_search_conditions(term, options[:basic_conditions], options[:column] || 'name')
        query = searched_class.where(conditions)
        query = query.select(options[:select]) if options[:select].present?
        query = options[:uniq] ? query.uniq : query
        query.count
      end

      def default_search_conditions(term, basic_conditions, columns)
        term_filter = ''
        conditions = []
        columns = [columns] unless columns.is_a?(Array)
        unless term.nil?
          words = term.split(' ')
          words.each_with_index do |word, index|
            term_filter += ' AND ' if index > 0
            columns.each_with_index do |column, idx|
              term_filter += ' OR ' if idx > 0
              term_filter +=  "#{column} LIKE ?"
              conditions << "%#{word}%"
            end
          end
          term_filter = term_filter.empty? ? nil : "(#{term_filter})"
          basic_conditions_part = basic_conditions.present? ? "(#{basic_conditions }) " : nil
          conditions.unshift([term_filter, basic_conditions_part].compact.join(' AND '))
        end
      end

      def get_init_values(searched_class, ids, title_method=nil)
        ids = ids.split(',')
        if ids.size > 1
          result = []
          ids.each do |id|
            item = searched_class.find_by_id(id)
            if item.present?
              result << get_select2_hash(item, title_method, id)
            end
          end
          result
        elsif ids.size == 1
          item = searched_class.find_by_id(ids[0])
          if item.present?
            get_select2_hash(item, title_method, ids[0])
          else
            nil
          end
        else
          nil
        end
      end

      def get_select2_hash(item, title_method, id)
        if item.respond_to?(:to_select2) && title_method.nil?
          item.to_select2
        else
          title_method ||= :name
          { text: item.send(title_method), id: id }
        end
      end
    end
  end
end