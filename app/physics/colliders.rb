# frozen_string_literal: true

require_relative 'colliders/base'
require_relative 'colliders/circle'
require_relative 'colliders/polygon'
require_relative 'colliders/algebraic_collider'
require_relative 'colliders/sum_collider'
require_relative 'colliders/product_collider'
require_relative 'colliders/difference_collider'

module Physics
  module Colliders
    # Aliases using set-theoretic naming
    UnionCollider = SumCollider
    IntersectionCollider = ProductCollider

    class << self
      def circle(center, radius)
        Circle.new(center, radius)
      end
      def polygon(*points)
        Polygon.new(*points)
      end
      def aabb(aabb_hash, relative_to: {x: 0, y: 0})
        relative_x = aabb_hash.x - relative_to.x
        relative_y = aabb_hash.y - relative_to.y
        bl = [relative_x, relative_y]
        tr = [relative_x + aabb_hash[:w], relative_y + aabb_hash[:h]]
        Polygon.new(
          # BL
          [relative_x, relative_y],
          # BR
          [tr[0], relative_y],
          # TR
          tr,
          # TL
          [relative_x, tr[1]]
        )
      end
      def sum(*colliders)
        SumCollider.new(*colliders)
      end
      def product(*colliders)
        ProductCollider.new(*colliders)
      end
      def difference(*colliders)
        DifferenceCollider.new(*colliders)
      end
      alias_method :union, :sum
      alias_method :intersection, :product
    end
  end
end
