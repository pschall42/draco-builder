# frozen_string_literal: true

module Physics
  class Transform
    class Vector
      attr_accessor :x, :y
      def initialize(x, y)
        raise "Cannot initialize with nil value!" if x.nil? || y.nil?
        @x, @y = x, y
      end

      # Allow construction from an Array, Hash, or itself
      def self.from(vector)
        # Explictly allow initializing from only Arrays, Hashes, or the same class
        case vector
        when Array
          self.new(*vector)
        when Hash
          self.new(*vector.values_at(:x, :y))
        when self
          self.new(vector.x, vector.y)
        else
          raise "Cannot initialize #{self.name} from #{vector.inspect}"
        end
      end

      # Allow array-like access
      def [](idx)
        v_attr = [:x, :y][idx]
        self.send(v_attr)
      end
      def []=(idx, value)
        v_attr = [:x=, :y=][idx]
        self.send(v_attr, value)
      end

      # Allow converting to Hash and Array representations
      def to_a
        [self.x, self.y]
      end
      def to_h
        {x: self.x, y: self.y}
      end
      def to_affine_vector
        [self.x, self.y, 1]
      end

      # Algebraic Properties
      def +(other)
        case other
        when Array
          self.class.new(self.x + other[0], self.y + other[1])
        when Hash
          self.class.new(self.x + other[:x], self.y + other[:y])
        when self.class
          self.class.new(self.x + other.x, self.y + other.y)
        end
      end
      def -@
        self.new(-self.x, -self.y)
      end
      def -(other)
        case other
        when Array
          self.class.new(self.x - other[0], self.y - other[1])
        when Hash
          self.class.new(self.x - other[:x], self.y - other[:y])
        when self.class
          self.class.new(self.x - other.x, self.y - other.y)
        end
      end
      def *(other)
        case other
        when Numeric
          self.class.new(self.x * other, self.y * other)
        when Array
          self.class.new(self.x * other[0], self.y * other[1])
        when Hash
          self.class.new(self.x * other[:x], self.y * other[:y])
        when self.class
          self.class.new(self.x * other.x, self.y * other.y)
        end
      end
      def /(other)
        case other
        when Numeric
          self.class.new(self.x / other, self.y / other)
        when Array
          self.class.new(self.x / other[0], self.y / other[1])
        when Hash
          self.class.new(self.x / other[:x], self.y / other[:y])
        when self.class
          self.class.new(self.x / other.x, self.y / other.y)
        end
      end

      def zero?
        self.x.zero? && self.y.zero?
      end




      def scalar_product(other)
      end
      def dot_product(other)
      end
      def cross_product(other)
      end

    end

    class Position < Vector; end
    class Scale < Vector; end
  end
end
