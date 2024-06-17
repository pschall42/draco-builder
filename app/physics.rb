# frozen_string_literal: true

require_relative 'math_ext'
require_relative 'physics/colliders'
require_relative 'physics/transform'

module Physics
  class << self
    # Object init
    def transform(*args)
      if args.size == 1
        case args[0]
        when Array
          # Either (position, rotation, scale) tuple or a transformation matrix
          if (args[0].size == 3) && args[0][1].is_a?(Numeric)
            # Must be (position, rotation, scale tuple)
            Transform.new(*args[0])
          else
            # Must be a transformation matrix
            Transform.from(args[0])
          end
        when Transform, Hash
          Transform.from(args)
        end
      else
        # Either (position, rotation, scale) tuple or a transformation matrix
        if (args.size == 3) && args[1].is_a?(Numeric)
          # Must be (position, rotation, scale tuple)
          Transform.new(*args)
        else
          # Must be a transformation matrix
          Transform.from(args)
        end
      end
    end

    def position(*args)
      (args.size == 1) ? Transform::Position.from(args[0]) : Transform::Position.new(*args)
    end
    def rotation(angle)
      {
        rotation: {x: 0, y: 0},
        angle_rotation: {theta: angle},
        scale_rotation: {x: 0, y: 0}
      }
      {theta: angle}
    end
    def scale(*args)
      (args.size == 1) ? Transform::Scale.from(args[0]) : Transform::Scale.new(*args)
    end

    def motion(game_object)
      # puts "motion #{game_object.inspect}"
      # Raise errors if there are multiple component definitions between regular components and transforms
      # if obj_hash.key?(:transforms) && integrate_hash

      # Use transforms if available for numeric integration
      # integrate_hash = obj_hash.key?(:transforms) ? obj_hash.merge(obj_hash[:transforms].reduce({}){|acc, (component_key, component_transform)|
      #   component_transform.to_integration_hash(component_key).each{|icomp_key, icomp_value|
      #     # icomp_key - integration component key
      #     # icomp_value - integration component value (should be a Hash)
      #     acc[icomp_key] = icomp_value
      #   }
      #   acc
      # }) : obj_hash
      integrate_hash = game_object.to_integration_hash
      # puts "integrate_hash: #{integrate_hash.inspect}"

      # Integrate the motion components
      integration_mapping = {
        # Linear mechanics
        position: :velocity,
        velocity: :acceleration,
        acceleration: :jerk,
        jerk: :snap,
        snap: :crackle,
        crackle: :pop,
        # Angular mechanics
        angle_position: :angle_velocity,
        angle_velocity: :angle_acceleration,
        angle_acceleration: :angle_jerk,
        angle_jerk: :angle_snap,
        angle_snap: :angle_crackle,
        angle_crackle: :angle_pop
      }
      components = MathExt.numeric_integration!(integrate_hash, integration_mapping)
      # puts "\tintegrate_hash:\t#{integrate_hash.inspect}\n\n\tcomponents:\t#{components.inspect}"

      # Set motion components
      # all_component_keys = integration_mapping.reduce({}){|acc, (k,v)|
      #   acc[k] = acc[v] = 1
      #   acc
      # }.keys
      # all_component_keys.each{|component_key|
      #   obj_hash[:transforms][component_key] ||= Physics::Transform.zero
      #   # Position
      #   obj_hash[:transforms][component_key].position.x = components.dig(component_key, :x) if !components.dig(component_key, :x).nil?
      #   obj_hash[:transforms][component_key].position.y = components.dig(component_key, :y) if !components.dig(component_key, :y).nil?
      #   # Rotation
      #   obj_hash[:transforms][component_key].rotation = components.dig(:"angle_#{component_key}", :theta) if !components.dig(:"angle_#{component_key}", :theta).nil?
      #   # Scale
      #   obj_hash[:transforms][component_key].scale.x = components.dig(:"scale_#{component_key}", :x) if !components.dig(:"scale_#{component_key}", :x).nil?
      #   obj_hash[:transforms][component_key].scale.y = components.dig(:"scale_#{component_key}", :y) if !components.dig(:"scale_#{component_key}", :y).nil?
      # }

      # Set motion components
      components.each{|component_key, hash|
        before_value = game_object.send(component_key)
        case before_value
        when Physics::Transform::Vector
          before_value.x = hash[:x] || 0
          before_value.y = hash[:y] || 0
        else
          game_object.send("#{component_key}=", hash[:theta] || 0)
        end
      }
    end

    # def intersecting?(obj_hash_1, obj_hash_2)
    #   # Possibilities for a Collider:
    #   #   * A collider does not exist
    #   #   * A collider exists and is using the object's local space
    #   #   * A collider exists and has already been corrected to use the global space
    #   # Possibilities for a Transform
    #   #   * A position transform does not exist
    #   #   * A position transform exists
    #   # Possibilities for individual Position and Scale Hash components
    #   #   * A position/scale hash component does not exist
    #   #   * A position/scale hash component exists
    #   # Could also just be a Hash with :x, :y, :w, :h components
    #   #
    #   # General policy here is that if there is ever more than 1 possibility for something to raise an error, otherwise we prioritize the data in the following order:
    #   #   1. Transform (Any intersection with Collider, AABB intersection otherwise)
    #   #   2. Collider (Any intersection)
    #   #   3. Position/Scale Hashes (Any intersection with collider, AABB intersections otherwise)
    #   #   4. Hash :x, :y, :w, :h (AABB intersections only)
    #   position_transform_obj_1 = obj_hash_1.dig(:transforms, :position)
    #   position_transform_obj_2 = obj_hash_2.dig(:transforms, :position)
    #   collider_obj_1 = obj_hash_1[:collider]
    #   collider_obj_2 = obj_hash_2[:collider]
    #   # # Extract Components that may conflict with the Transforms
    #   # position_hash_obj_1, rotation_hash_obj_1, scale_hash_obj_1 = obj_hash_1.values_at(:position, :rotation, :angle)
    #   # position_hash_obj_2, rotation_hash_obj_2, scale_hash_obj_2 = obj_hash_2.values_at(:position, :rotation, :angle)
    #   # # If any of them conflict, raise an error
    #   # if [position_hash_obj_1, rotation_hash_obj_1, scale_hash_obj_1].any?{|comp| !comp.nil? }
    #   # else
    #   # end
    #   # # Create a virtual AABB collider if none is present
    #   # # Create a virtual position Transform if none is present

    #   collider_global_obj_1 = self.apply_transform(position_transform_obj_1, collider_obj_1)
    #   collider_global_obj_2 = self.apply_transform(position_transform_obj_2, collider_obj_2)
    #   puts "\n\ncollider_obj_1: #{collider_obj_1.center.inspect}"
    #   puts "\ncollider_obj_2\: #{collider_obj_2.center.inspect}\n\n"

    #   puts "\n\ncollider_global_obj_1: #{collider_global_obj_1.center.inspect}"
    #   puts "\ncollider_global_obj_2: #{collider_global_obj_2.center.inspect}\n\n"
    #   self.collider_intersecting?(collider_global_obj_1, collider_global_obj_2)
    # end

    def intersecting?(game_object_1, game_object_2)
      # self.aabb_intersecting_aabb?(game_object_1.aabb, game_object_2.aabb) && self.collider_intersecting?(game_object_1.global_collider, game_object_2.global_collider)
      self.collider_intersecting?(game_object_1.global_collider, game_object_2.global_collider)
    end

    def simple_intersecting?(obj_hash_1, obj_hash_2)
      Geometry.intersect_rect?(obj_hash_1[:position].merge(obj_hash_1[:scale]), obj_hash_2[:position].merge(obj_hash_2[:scale]))
    end

    def collider_intersecting?(collider_1, collider_2)
      case collider_1
      when Colliders::Circle
        self.circle_intersecting?(collider_1, collider_2)
      when Colliders::Polygon
        self.polygon_intersecting?(collider_1, collider_2)
      when Colliders::SumCollider
        self.sum_collider_intersecting?(collider_1, collider_2)
      when Colliders::ProductCollider
        self.product_collider_intersecting?(collider_1, collider_2)
      when Colliders::DifferenceCollider
        self.difference_collider_intersecting?(collider_1, collider_2)
      else
        raise "Missing collision logic between #{collider_1.class.name} and #{collider_2.class.name}"
      end
    end

    def circle_intersecting?(circle_collider, other_collider)
      case other_collider
      when Colliders::Circle
        # center_dist = Geometry.distance(circle_collider.center, other_collider.center)
        # center_dist < (circle_collider.radius + other_collider.radius)
        center_dist_square = Geometry.distance_squared(circle_collider.center, other_collider.center)
        center_dist_square < (circle_collider.radius + other_collider.radius) ** 2
      when Colliders::Polygon
        # See: https://stackoverflow.com/a/402019
        # First check if the AABB intersects, if not there's no reason to continue checking
        return false if !self.aabb_intersecting_circle?(other_collider.aabb, circle_collider)
        other_collider.edges.any?{|edge|
          start_point, end_point = edge
          Geometry.circle_intersect_line?(circle_collider, {
            x: start_point[0], y: start_point[1],
            x2: end_point[0], y2: end_point[1]
          })
        }
      when Colliders::AlgebraicCollider
        # Run through the algebra by swapping the order of the arguments
        self.collider_intersecting?(other_collider, circle_collider)
      else
        raise "Missing circle collision logic for #{other_collider.class.name}!"
      end
    end

    def polygon_intersecting?(polygon_collider, other_collider)
      case other_collider
      when Colliders::Circle
        # See: https://stackoverflow.com/a/402019
        # First check if the AABB intersects, if not there's no reason to continue checking
        return false if !self.aabb_intersecting_circle?(polygon_collider.aabb, other_collider)
        polygon_collider.edges.any?{|edge|
          start_point, end_point = edge
          Geometry.circle_intersect_line?(other_collider, {
            x: start_point[0], y: start_point[1],
            x2: end_point[0], y2: end_point[1]
          })
        }
      when Colliders::Polygon
        # First check if their AABBs intersect, if not there's no reason to continue checking
        return false if !self.aabb_intersecting_aabb?(polygon_collider.aabb, other_collider.aabb)
        # Use the Separating Axis Theorem
        # See:
        #   https://developer.mozilla.org/en-US/docs/Games/Techniques/2D_collision_detection
        #   https://www.sevenson.com.au/programming/sat/
        #   https://www.metanetsoftware.com/technique/tutorialA.html
        #   https://www.metanetsoftware.com/2016/n-tutorial-a-collision-detection-and-response
        #   https://code.tutsplus.com/collision-detection-using-the-separating-axis-theorem--gamedev-169t
        #     https://www.mathjax.org/#demo
        #   https://dyn4j.org/2010/01/sat/
        #   https://programmerart.weebly.com/separating-axis-theorem.html
        #   https://stackoverflow.com/a/402019
        #   https://ericleong.me/research/circle-circle/
        axes = polygon_collider.outward_normals + other_collider.outward_normals
        axes.all?{|axis|
          polygon_collider_projection = MathExt::Vector.project_onto_axis(axis, polygon_collider.points)
          other_collider_projection = MathExt::Vector.project_onto_axis(axis, other_collider.points)
          is_intersecting = (polygon_collider_projection.max >= other_collider_projection.min) && (polygon_collider_projection.min <= other_collider_projection.max)

          is_intersecting
        }
      when Colliders::AlgebraicCollider
        # Run through the algebra by swapping the order of the arguments
        self.collider_intersecting?(other_collider, circle_collider)
      else
        raise "Missing polygon collision logic for #{other_collider.class.name}!"
      end
    end

    def aabb_intersecting_circle?(aabb, circle_collider)
      aabb_max_x = aabb[:x] + aabb[:w]
      aabb_max_y = aabb[:y] + aabb[:h]
      center = circle_collider.center
      center_in_aabb = (aabb[:x] <= center[0]) && (center[0] <= aabb_max_x) && (aabb[:y] <= center[1]) && (center[1] <= aabb_max_y)
      return true if center_in_aabb
      return true if Geometry.circle_intersect_line?(circle_collider, {x: aabb[:x], y: aabb[:y], x2: aabb_max_x, y2: aabb[:y]}) # Bottom line
      return true if Geometry.circle_intersect_line?(circle_collider, {x: aabb_max_x, y: aabb[:y], x2: aabb_max_x, y2: aabb_max_y}) # Right line
      return true if Geometry.circle_intersect_line?(circle_collider, {x: aabb[:x], y: aabb_max_y, x2: aabb_max_x, y2: aabb_max_y}) # Top line
      return true if Geometry.circle_intersect_line?(circle_collider, {x: aabb[:x], y: aabb[:y], x2: aabb_max_x, y2: aabb[:y]}) # Left line
      false # Otherwise false
    end
    def aabb_intersecting_aabb?(aabb_1, aabb_2)
      Geometry.intersect_rect?(aabb_1, aabb_2)
    end

    def sum_collider_intersecting?(sum_collider, other_collider)
      sum_collider.colliders.any?{|collider| self.collider_intersecting?(collider, other_collider) }
    end
    def product_collider_intersecting?(product_collider, other_collider)
      product_collider.colliders.any?{|collider| self.collider_intersecting?(collider, other_collider) }
    end
    # Technically a bit of a misnomer, because this is used to detect the absense of a collision (anything outside of the collision area).
    def difference_collider_intersecting?(difference_collider, other_collider)
      difference_collider.colliders.none?{|collider| self.collider_intersecting?(collider, other_collider) }
    end
    alias_method :union_collider_intersecting?, :sum_collider_intersecting?
    alias_method :intersection_collider_intersecting?, :product_collider_intersecting?

    # def handle_collisions(obj_hashes_1, obj_hashes_2, &block)
    #   obj_hashes_1.each{|obj_hash_1|
    #     obj_hashes_2.each{|obj_hash_2|
    #       # Attempt collisions using the collider components first, otherwise use simple intersection testing
    #       if obj_hash_1.key?(:collider) && obj_hash_2.key?(:collider)
    #         # puts "Collider collision"
    #         # block.call(obj_hash_1, obj_hash_2) if self.collider_intersecting?(obj_hash_1[:collider], obj_hash_2[:collider])
    #         block.call(obj_hash_1, obj_hash_2) if self.intersecting?(obj_hash_1, obj_hash_2)
    #       elsif self.simple_intersecting?(obj_hash_1, obj_hash_2)
    #         # puts "Simple collision"
    #         block.call(obj_hash_1, obj_hash_2)
    #       end
    #     }
    #   }
    # end
    def handle_collisions(game_objects_1, game_objects_2, &block)
      is_game_objects_1_shorter = game_objects_1.size < game_objects_2.size
      small_set, large_set = is_game_objects_1_shorter ? [game_objects_1, game_objects_2] : [game_objects_2, game_objects_1]

      # Constructing a quad tree from the smaller set tends to do better
      quad_tree = Geometry.quad_tree_create(small_set.map{|small_set_object|
        small_set_object.aabb.merge(game_object: small_set_object)
      })
      # puts "quad_tree: #{quad_tree.inspect}"
      large_set.each{|large_set_object|
        collisions = Geometry.find_all_intersect_rect_quad_tree(large_set_object.aabb, quad_tree)
        collisions.each{|small_set_object_aabb_ref|
          small_set_object = small_set_object_aabb_ref[:game_object]
          if self.intersecting?(large_set_object, small_set_object)
            # Pass them in the same order
            game_object_1, game_object_2 = is_game_objects_1_shorter ? [small_set_object, large_set_object] : [large_set_object, small_set_object]
            block.call(game_object_1, game_object_2)
          end
        }
      }



      # game_objects_1.each{|game_object_1|
      #   game_objects_2.each{|game_object_2|
      #     if self.intersecting?(game_object_1, game_object_2)
      #       block.call(game_object_1, game_object_2)
      #     end
      #   }
      # }
    end


    # TODO:
    #   * Finish this up
    #   * Change everything to use a proper Transform instead of just position data
    #   * Change integration logic to modify the Transform
    #     - Can rotation be additive using this logic??? If so, it would work for angular change as well
    #
    #     https://phys.libretexts.org/Bookshelves/University_Physics/University_Physics_(OpenStax)/Book%3A_University_Physics_I_-_Mechanics_Sound_Oscillations_and_Waves_(OpenStax)/09%3A_Linear_Momentum_and_Collisions/9.07%3A_Types_of_Collisions
    #     about:privatebrowsing
    #     https://docs.dragonruby.org/#/api/numeric?id=to_si
    #     https://dragonruby.org/#/
    #     https://dragonruby.org/toolkit/game
    #     https://github.com/DragonRuby/dragonruby-game-toolkit-contrib
    #     https://duckduckgo.com/?t=lm&q=mruby+matrix&ia=web
    #     https://github.com/mruby/mruby
    #     https://mruby.org/docs/
    #     https://mruby.org/docs/articles/executing-ruby-code-with-mruby.html
    #     https://github.com/mruby/microcontroller-peripheral-interface-guide
    #     https://mruby.org/docs/api/
    #     https://unity.com/how-to/enhanced-physics-performance-smooth-gameplay
    #     https://docs.unity.com/
    #     https://docs.unity3d.com/Manual/class-Transform.html
    #     https://docs.unity3d.com/ScriptReference/index.html
    #     https://www.cuemath.com/algebra/multiplication-of-vectors/
    #     https://duckduckgo.com/?t=lm&q=apply+transform+to+arbitrary+polygon&ia=web
    #     https://stackoverflow.com/questions/6830480/scaling-an-arbitrary-polygon
    #     https://en.wikipedia.org/wiki/Scaling_%28geometry%29
    #     https://gamedev.net/forums/topic/614791-how-to-scale-a-polygon/4883897/
    #     https://en.wikipedia.org/wiki/Homothety
    #     https://stackoverflow.com/questions/43157092/applying-transformation-matrix-to-a-list-of-points-in-opencv-python
    #     about:privatebrowsing
    #     https://gamedev.stackexchange.com/questions/26951/calculating-the-2d-edge-normals-of-a-triangle
    #     https://stackoverflow.com/questions/22838071/robust-polygon-normal-calculation
    #     https://www.khronos.org/opengl/wiki/Calculating_a_Surface_Normal
    #     https://stackoverflow.com/questions/11548309/guarantee-outward-direction-of-polygon-normals
    #     https://www.codezealot.org/archives/55/#sat-mtv
    #     https://stackoverflow.com/questions/1165647/how-to-determine-if-a-list-of-polygon-points-are-in-clockwise-order/1165943#1165943
    #     http://www.faqs.org/faqs/graphics/algorithms-faq/
    #     https://brilliant.org/wiki/properties-of-equilateral-triangles/
    #     https://duckduckgo.com/?q=vector+linear+component+product&t=lm&ia=web
    #     https://gamedev.net/forums/topic/541643-scaling-along-arbitrary-axis/
    #     https://gamedev.net/forums/topic/614791-how-to-scale-a-polygon/4883897/
    #     https://duckduckgo.com/?t=lm&q=linear+algebra+translation+rotation+scale&ia=web
    #     https://jonshiach.github.io/LA-book/pages/6.2_Rotation_reflection_and_translation.html
    #     https://jonshiach.github.io/LA-book/pages/6.1_Composite_transformations.html
    #     https://jonshiach.github.io/LA-book/pages/6.3_Translation.html
    #     https://math.stackexchange.com/questions/237369/given-this-transformation-matrix-how-do-i-decompose-it-into-translation-rotati
    #     https://math.stackexchange.com/questions/13150/extracting-rotation-scale-values-from-2d-transformation-matrix/13165#13165
    #     https://duckduckgo.com/?t=lm&q=matrix+multiplication&ia=web
    #     https://en.wikipedia.org/wiki/Matrix_multiplication
    #     https://duckduckgo.com/?t=lm&q=ruby+matrix+multiply&ia=web
    #     https://ruby-doc.org/stdlib-2.6.8/libdoc/matrix/rdoc/Matrix.html#method-c-scalar
    #     https://stackoverflow.com/questions/53072025/how-to-perform-a-matrix-multiplicaton-on-ruby
    #     https://ruby-doc.org/3.2.3/gems/matrix/Matrix.html

    #     https://ruby-doc.org/stdlib-2.5.1/libdoc/matrix/rdoc/Matrix.html
    #     https://github.com/ruby/ruby/tree/master
    #     https://github.com/ruby/matrix/tree/master/lib/matrix
    #     https://github.com/ruby/matrix/blob/master/lib/matrix.rb
    #     https://en.wikipedia.org/wiki/Cartesian_product
    #     https://duckduckgo.com/?q=decompose+a+matrix+into+translation%2C+rotation%2C+and+scaling+matrices&t=lm&ia=web
    #     https://www.mathworks.com/matlabcentral/answers/353930-how-can-i-decompose-a-transformation-matrix-given-by-the-imregtform-function
    #     https://leimao.github.io/blog/Matrix-Rotation-Scaling-Theorem/
    #     http://facweb.cs.depaul.edu/andre/gam374/extractingTRS.pdf
    #     https://www.mathematics-monster.com/lessons/using_the_cosine_function_to_find_the_angle.html
    #     https://colab.research.google.com/drive/1ImBB-N6P9zlNMCBH9evHD6tjk0dzvy1_
    #     https://github.com/ruby/matrix/blob/master/lib/matrix/eigenvalue_decomposition.rb
    #     https://github.com/ruby/matrix/blob/master/lib/matrix/lup_decomposition.rb
    #     https://www.khanacademy.org/math/precalculus/x9e81a4f98389efdf:matrices/x9e81a4f98389efdf:multiplying-matrices-by-matrices/e/multiplying_a_matrix_by_a_matrix

    # Returns an object of the same type as the target object
    def apply_transform(transform, target_obj, relative_to: nil)
      # relative_to only really applies to Polygons and Algebraic Colliders
      case target_obj
      when Physics::Transform::Vector
        x, y, _z = MathExt::Matrix.multiply(transform.transformation_matrix, target_obj.to_affine_vector)
        Physics::Transform::Vector.new(x, y)
      when Physics::Transform
        transform.compose(target_obj)
      when Colliders::Circle
        relative_to ||= target_obj.center.to_a
        local_center = target_obj.center.to_a.each_with_index.map{|v, idx| v - relative_to[idx]}
        local_center_affine = [].fill(0..2){|idx| local_center[idx] || (idx == 2 ? 1 : 0)}

        # Find the new local center, then translate back to global coords
        new_local_center_x, new_local_center_y, _new_center_z = MathExt::Matrix.multiply(transform.transformation_matrix, local_center_affine).flatten
        # puts "\n\nnew_local_center_x: #{new_local_center_x.inspect}\n\nnew_local_center_y: #{new_local_center_y.inspect}\n\nrelative_to: #{relative_to.inspect}\n\n"
        new_global_center_x = new_local_center_x + relative_to[0]
        new_global_center_y = new_local_center_y + relative_to[1]
        # Don't want to bother right now with the complexities of Ellipse colliders, so just take the average scale and multiply the radius by that
        scale_array = transform.scale.to_a
        new_radius = (scale_array.sum / scale_array.size.to_f) * target_obj.radius
        # Rotation doesn't matter because a circle is a circle
        Colliders.circle([new_global_center_x, new_global_center_y], new_radius)
      when Colliders::Polygon
        # Need to obtain the transform vector of every edge, apply the scale to that vector, then recalculate the points
        relative_to ||= target_obj.center
        # target_obj.edges.map{|edge|
        #   start_point, end_point = edge
        #   sx, sy = start_point
        #   ex, ey = end_point
        #   edge_diff = [ex - sx, ey - sy]
        #   scaled_edge_diff = edge_diff.each_with_index.map{|axis, idx| axis * transform.scale[idx] }
        # }
        Colliders.polygon(*target_obj.points.map{|point|
          local_point = point.each_with_index.map{|v, idx| v - relative_to[idx]}
          local_point_affine = [].fill(0..2){|idx| local_point[idx] || (idx == 2 ? 1 : 0)}
          new_local_x, new_local_y, _new_local_z = MathExt::Matrix.multiply(transform.transformation_matrix, local_point_affine).flatten
          new_global_x = new_local_x + relative_to[0]
          new_global_y = new_local_y + relative_to[1]
          [new_global_x, new_global_y]
        })
      when Colliders::AlgebraicCollider
        relative_to ||= target_obj.center
        target_obj.class.new(target_obj.colliders.map{|collider| self.apply_transform(transform, collider, relative_to: relative_to) })
      end
    end
    def apply_transform!(transform, collider)

    end
  end
end