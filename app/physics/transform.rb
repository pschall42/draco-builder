# frozen_string_literal: true

require_relative 'transform/vector'

# Helpful reference: https://learnopengl.com/Getting-started/Transformations
module Physics
  class Transform

    attr_accessor :position, :rotation, :scale
    def initialize(position, rotation, scale)
      # We want to make sure we're duplicating data, not sharing references because that can lead to some really nasty bugs
      @position = Position.from(position)
      @rotation = (rotation <=> 0) * (rotation.abs % 360) # Just an angle, not a vector (because we're working in 2D)
      @scale = Scale.from(scale)
    end

    # Identity Transform, useful for testing.
    def self.identity
      Transform.new([0, 0], 0, [1, 1])
    end

    # Used when initializing Transforms during Physics integration
    def self.zero
      Transform.new([0, 0], 0, [0, 0])
    end

    # Takes and creates a new Physics::Transform from an input object, which can be either another Physics::Transform, integration hash (described in the comments for :from_integration_hash), or a transformation matrix (described in the comments for :from_transformation_matrix).
    #
    # When attempting to parse an integration hash, it can accept an optional integration_hash_component_key. If not given, it will attempt to find a candidate for the integration hash based on the components within the hash. If there are multiple candidates for a component key, it will raise an error.
    def self.from(object, integration_hash_component_key: nil)
      case object
      when Transform
        self.from_transform(object)
      when Hash # Integration Hash
        # Infer the component key if not provided, raising an error if it cannot infer the component key either because there are too many possible candidates or there are no suitable matching components.
        integration_hash_component_key ||= lambda{
          # First attempt to infer from angle and scale components
          candidates = object.reduce([]){|acc, (comp_key, comp_value)|
            has_coord_axes = [:x, :y].all?{|coord_axis| comp_value.key?(coord_axis)}
            comp_key_str = comp_key.to_s
            if (comp_key_str.index('scale_') == 0) && has_coord_axes
              # Matches scale_<component_key>
              candidate = comp_key_str[6..-1].to_sym # Extract everything after "scale_"
              acc << candidate if !acc.include?(candidate)
            elsif has_coord_axes
              # Matches <component_key>
              acc << comp_key if !acc.include?(comp_key)
            elsif (comp_key_str.index('angle_') == 0) && comp_value.key?(:theta)
              # Matches angle_<component_key>
              candidate = comp_key_str[6..-1].to_sym # Extract everything after "angle_"
              acc << candidate if !acc.include?(candidate)
            end
            # Raise an error if we ever have more than 1 candidate
            raise "Cannot infer #{self.name} from integration hash #{object.inspect}, please explicitly provide :integration_hash_component_key!" if acc.size > 1
            acc
          }
          # Raise an error if there aren't any candidates
          raise "Cannot infer #{self.name} from integration hash #{object.inspect}, no possible components could be matched!" if candidates.empty?
          # Return the only candidate
          candidates[0]
        }.call()
        self.from_integration_hash(object, integration_hash_component_key)
      when Array # Transformation Matrix
        self.from_transformation_matrix(object)
      else # Invalid input
        raise "Cannot construct #{self.name} from #{object.class.name}: #{object.inspect}"
      end
    end

    # Creates a new Physics::Transform from an existing Physics::Transform
    def self.from_transform(object)
      # Just generating a new transform
      self.new(
        object.position,
        object.rotation,
        object.scale
      )
    end

    # Creates a new Physics::Transform from an integration hash, which is just a regular Hash that matches the following structure:
    #   {
    #     <component_key>: {x: <position.x>, y: <position.y>},
    #     angle_<component_key>: {theta: <rotation>},
    #     scale_<component_key>: {x: <position.x>, y: <position.y>},
    #   }
    # Such a Hash can be output by one of the following methods:
    #   * Physics::Transform#to_integration_hash
    #   * MathExt.numeric_integration
    #   * MathExt.numeric_integration!
    def self.from_integration_hash(integration_hash, component_key)
      position_component_key = component_key
      angle_component_key = :"angle_#{component_key}"
      scale_component_key = :"scale_#{component_key}"

      self.new(
        integration_hash[position_component_key],
        integration_hash[angle_component_key][:theta],
        integration_hash[scale_component_key]
      )
    end

    # Creates a new Physics::Transform from a transformation matrix, which is just a regular Array that matches the following structure:
    #   [
    #     [s.x * cos(theta), -s.y * sin(theta), t.x],
    #     [s.x * sin(theta),  s.y * cos(theta), t.y],
    #     [               0,                 0,   1]
    #   ]
    def self.from_transformation_matrix(transformation_matrix)
      # To extract each component from the transformation matrix, we follow the factorization found here:
      #   http://facweb.cs.depaul.edu/andre/gam374/extractingTRS.pdf
      tm = transformation_matrix # alias to clarify code
      # If we reverse the process, we get this for the translation (position) matrix:
      #   translation_matrix = [
      #     [1, 0, tm[0][2]],
      #     [0, 1, tm[1][2]],
      #     [0, 0,        1]
      #   ]
      # So the position is simple
      position = [tm[0][2], tm[1][2]]
      # Scale and Rotation are more difficult
      scale = [
        ((tm[0][0] ** 2) + (tm[1][0] ** 2) + (tm[2][0] ** 2)) ** 0.5,
        ((tm[0][1] ** 2) + (tm[1][1] ** 2) + (tm[2][1] ** 2)) ** 0.5
      ]
      cos_angle_radians = tm[0][0] / scale[0]
      angle_radians = Math.acos(cos_angle_radians)
      rotation = angle_radians.to_degrees
      # Return a new Transform
      self.new(position, rotation, scale)
    end

    # Converts a Physics::Transform into a Hash with components suitable for running through MathExt.numeric_integration or MathExt.numeric_integration!
    #
    #   component_key:
    #     :position | :velocity | :acceleration | :jerk | :snap | :crackle | :pop
    #   returns:
    #     {
    #       <component_key>: {x: <position.x>, y: <position.y>},
    #       angle_<component_key>: {theta: <rotation>},
    #       scale_<component_key>: {x: <position.x>, y: <position.y>},
    #     }
    def to_integration_hash(component_key)
      position_component_key = component_key
      angle_component_key = :"angle_#{component_key}"
      scale_component_key = :"scale_#{component_key}"
      {
        position_component_key => self.position.to_h,
        angle_component_key => {theta: self.rotation},
        scale_component_key => self.scale.to_h
      }
    end

    def zero?
      self.position.zero? && self.rotation.zero? && self.scale.zero?
    end

    # def compose(other_transform)
    #   c_mm = self.compose_by_matrix_multiplication(other_transform)
    #   c_ca = self.compose_by_component_addition(other_transform)

    # end

    # Composes 2 Physics::Transform objects into a single Physics::Transform
    def compose_by_component_addition(other_transform)
      self.class.new(
        self.position + other_transform.position,
        self.rotation + other_transform.rotation,
        self.scale * other_transform.scale
      )
    end
    alias_method :compose, :compose_by_component_addition

    def compose_by_matrix_multiplication(other_transform)
      # Return a new Transform based on the multiplication of their transformation matrices. This needs to be done component-wise, then find the appropriate transformation matrix.
      # Because of how matrix multiplication works, the following properties arise:
      #   * Translation is additive
      #   * Rotation is additive
      #   * Scaling is multiplicative
      # Ultimately this means that this should be equivalent to the :compose_by_component_addition method. The only real reason this exists is for correctness checking in tests.
      self.class.from(MathExt::Matrix.multiply(
        MathExt::Matrix.multiply(self.translation_matrix, other_transform.translation_matrix),
        MathExt::Matrix.multiply(self.rotation_matrix, other_transform.rotation_matrix),
        MathExt::Matrix.multiply(self.scaling_matrix, other_transform.scaling_matrix)
      ))
    end

    def +(other)
      case other
      when Physics::Transform::Position
        self.class.new(
          self.position + other,
          self.rotation,
          self.scale
        )
      when Physics::Transform::Scale
        self.class.new(
          self.position,
          self.rotation,
          self.scale + other
        )
      when Hash
        other_transform = self.from(other)
        self.class.new(
          self.position + other.position,
          self.rotation + other.rotation,
          self.scale + other.scale
        )
      end
    end

    # Applies a Physics::Transform to an object
    def apply(object)
      Physics.apply_transform(self, object)
    end
    def apply!(object)
      Physics.apply_transform!(self, object)
    end

    # The full composite transformation matrix, used when computing the location of a Collider
    def transformation_matrix
      # First scale, then rotate, then translate. The order of application to a vector is actually the reverse order of the multiplication, so the first operation to the matrix multiply operation is the last one applied to the target vector.
      # MathExt::Matrix.multiply(
      #   self.translation_matrix,
      #   self.rotation_matrix,
      #   self.scaling_matrix
      # )
      # Optimized version, rather than looping through and allocating/freeing extra arrays unnecessarily every frame
      angle_radians = self.rotation.to_radians
      cos_angle_radians = Math.cos(angle_radians)
      sin_angle_radians = Math.sin(angle_radians)
      [
        [self.scale.x * cos_angle_radians,  -self.scale.y * sin_angle_radians,  self.position.x],
        [self.scale.x * sin_angle_radians,   self.scale.y * cos_angle_radians,  self.position.y],
        [                               0,                                  0,                1]
      ]
    end

    # The affine translation matrix representation of the position component
    def position_matrix
      [
        [1, 0, self.position.x],
        [0, 1, self.position.y],
        [0, 0,               1]
      ]
    end
    alias_method :translation_matrix, :position_matrix

    # The affine rotation matrix representation of the rotation component
    def rotation_matrix
      angle_radians = self.rotation.to_radians
      cos_angle_radians = Math.cos(angle_radians)
      sin_angle_radians = Math.sin(angle_radians)
      [
        [cos_angle_radians, -sin_angle_radians, 0],
        [sin_angle_radians,  cos_angle_radians, 0],
        [                 0,                 0, 1]
      ]
    end

    # The affine scaling matrix representation of the rotation component
    def scaling_matrix
      [
        [self.scale.x,            0, 0],
        [           0, self.scale.y, 0],
        [           0,            0, 1]
      ]
    end
  end
end