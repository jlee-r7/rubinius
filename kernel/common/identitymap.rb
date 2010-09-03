class Array

  # IdentityMap is customized for uniquely storing elements from an Array to
  # implement the following Array methods: #&, #|, #-, #uniq, and #uniq!
  #
  # The algorithm used is double hashing with an overflow array. For each
  # array element, the element, its hash value, and its ordinal in the
  # sequence of elements added to the map are stored.
  #
  # Methods are provided to test an element for inclusion in the map and to
  # delete an entry from the map. The contents of a map can be returned as an
  # array in the order the elements were added to the map.
  class IdentityMap
    attr_reader :size
    attr_reader :capacity

    Table = Rubinius::Tuple
    MIN_CAPACITY = 64

    def initialize(array, extra=0, capacity=MIN_CAPACITY)
      size = array.size + extra
      while capacity < size
        capacity <<= 1
      end
      capacity <<= 3

      @table    = Table.new capacity
      @mask     = capacity - 4
      @size     = 0
      @spill    = []
      @capacity = capacity

      load array
    end

    def match?(table, index, item_hash, item)
      item_hash == table[index] and item.eql? table[index+1]
    end
    private :match?

    # Returns true if +item+ matches any entry in the map.
    def include?(item)
      item_hash = item.hash

      index = item_hash & @mask
      return true if match? @table, index, item_hash, item

      index = item_hash.hash & @mask
      return true if match? @table, index, item_hash, item

      return false if @spill.empty?

      each_spill_index do |index|
        return true if match? @spill, index, item_hash, item
      end

      false
    end

    def delete_entry(table, index, item_hash, item)
      if match? table, index, item_hash, item
        table[index] = nil
        @size -= 1
        return true
      end

      false
    end
    private :delete_entry

    # If +item+ matches an entry, deletes the entry from the table and returns
    # true, otherwise returns false.
    def delete(item)
      item_hash = item.hash

      index = item_hash & @mask
      return true if delete_entry @table, index, item_hash, item

      index = item_hash.hash & @mask
      return true if delete_entry @table, index, item_hash, item

      return false if @spill.empty?

      each_spill_index do |index|
        return true if delete_entry @spill, index, item_hash, item
      end

      false
    end

    def insert(item)
      key_hash = item.hash

      index = key_hash & @mask
      if hash = @table[index]
        return if hash == key_hash and item.eql? @table[index+1]

        index = key_hash.hash & @mask
        if hash = @table[index]
          unless hash == key_hash and item.eql? @table[index+1]
            each_spill do |kh, x, i|
              return if kh == key_hash and item.eql? x
            end

            @spill << key_hash << item << @size
            @size += 1
          end

          return
        end
      end

      @table[index]   = key_hash
      @table[index+1] = item
      @table[index+2] = @size
      @size += 1
    end

    def each_spill
      i = @spill.start
      total = i + @spill.total
      tuple = @spill.tuple

      while i < total
        yield tuple.at(i), tuple.at(i+1), tuple.at(i+2)
        i += 3
      end
    end

    def each_spill_index
      i = 0
      total = @spill.total

      while i < total
        yield i
        i += 3
      end
    end

    # Addes each element of +array+ to the map. If an element of +array+ is
    # already in the map, the element is not added.
    def load(array)
      array.each { |x| insert x }
    end

    # Returns an Array containing every entry in the map. If passed +array+,
    # the contents will be replaced with the entries in the map. The size of
    # the passed array MUST be at least the size of the map.
    def to_array(array=nil)
      if array
        array.start = 0
        array.total = @size
      else
        array = Array.new @size
      end

      i = 0
      while i < @capacity
        array[@table[i+2]] = @table[i+1] if @table[i]
        i += 4
      end

      each_spill { |key_hash, item, index| array[index] = item if key_hash }

      array
    end
  end
end
