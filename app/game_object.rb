# frozen_string_literal: true

require_relative 'physics'

class GameObject
  TRANSFORMS = [:position, :velocity, :acceleration, :jerk, :snap, :crackle, :pop]

  attr_accessor :transforms, :unscaled_dimensions, :local_collider, :data, :sprite, :color

  def initialize(transforms: , dimensions: , collider: , sprite: , data: {}, color: {})
    @sprite = sprite
    # Copy all the transforms
    @transforms = TRANSFORMS.reduce({}){|acc, key|
      # acc[key] = transforms.key?(key) ? Physics::Transform.from(transforms[key]) : (key == :position) ? Physics::Transform.identity : Physics::Transform.zero
      acc[key] = Physics::Transform.from(transforms[key]) if transforms.key?(key)
      acc
    }
    # Copy unscaled dimensions
    @unscaled_dimensions = dimensions.slice(:w, :h)
    @local_collider = collider
    # Allow arbitrary data
    @data = data
    @color = color
  end

  # Defines the following methods for easier transform access:
  #   Position
  #     :position   :position=
  #     :angle    :angle=
  #     :scale    :scale=
  #   Velocity
  #     :velocity           :velocity=
  #     :angle_velocity     :angle_velocity=
  #     :angular_velocity   :angular_velocity=
  #     :scale_velocity     :scale_velocity=
  #     :scaling_velocity   :scaling_velocity=
  #   Acceleration
  #     :acceleration           :acceleration=
  #     :angle_acceleration     :angle_acceleration=
  #     :angular_acceleration   :angular_acceleration=
  #     :scale_acceleration     :scale_acceleration=
  #     :scaling_acceleration   :scaling_acceleration=
  #   Jerk
  #     :jerk           :jerk=
  #     :angle_jerk     :angle_jerk=
  #     :angular_jerk   :angular_jerk=
  #     :scale_jerk     :scale_jerk=
  #     :scaling_jerk   :scaling_jerk=
  #   Snap
  #     :snap           :snap=
  #     :angle_snap     :angle_snap=
  #     :angular_snap   :angular_snap=
  #     :scale_snap     :scale_snap=
  #     :scaling_snap   :scaling_snap=
  #   Crackle
  #     :crackle            :crackle=
  #     :angle_crackle      :angle_crackle=
  #     :angular_crackle    :angular_crackle=
  #     :scale_crackle      :scale_crackle=
  #     :scaling_crackle    :scaling_crackle=
  #   Pop
  #     :pop            :pop=
  #     :angle_pop      :angle_pop=
  #     :angular_pop    :angular_pop=
  #     :scale_pop      :scale_pop=
  #     :scaling_pop    :scaling_pop=
  TRANSFORMS.each do |method_name|
    linear_method_name = method_name
    angular_method_name = (method_name == :position) ? :angle : :"angle_#{method_name}"
    scaling_method_name = (method_name == :position) ? :scale : :"scale_#{method_name}"
    define_method(linear_method_name) do
      # Find or initialize the transform
      transform = (self.transforms[method_name] ||= (method_name == :position) ? Physics::Transform.identity : Physics::Transform.zero)
      # Return the position
      transform.position
    end
    define_method("#{linear_method_name}=") do |value|
      # Find or initialize the transform
      transform = (self.transforms[method_name] ||= (method_name == :position) ? Physics::Transform.identity : Physics::Transform.zero)
      # Extract [:x, :y] pair and write to the transform
      x, y = extract_xy(value, type: :position)
      transform.position.x = x
      transform.position.y = y
      # Return the position (for chaining)
      transform.position
    rescue => e
      raise "Cannot update #{self.class.name} #{linear_method_name} with #{value.class.name}: #{e.message}"
    end
    define_method(angular_method_name) do
      # Find or initialize the transform
      transform = (self.transforms[method_name] ||= (method_name == :position) ? Physics::Transform.identity : Physics::Transform.zero)
      # Return the rotation
      transform.rotation
    end
    define_method("#{angular_method_name}=") do |value|
      # Find or initialize the transform
      transform = (self.transforms[method_name] ||= (method_name == :position) ? Physics::Transform.identity : Physics::Transform.zero)
      # Write and return the rotation
      transform.rotation = value
    end

    define_method(scaling_method_name) do
      # Find or initialize the transform
      transform = (self.transforms[method_name] ||= (method_name == :position) ? Physics::Transform.identity : Physics::Transform.zero)
      # Return the position
      transform.scale
    end
    define_method("#{scaling_method_name}=") do |value|
      # Find or initialize the transform
      transform = (self.transforms[method_name] ||= (method_name == :position) ? Physics::Transform.identity : Physics::Transform.zero)
      # Extract [:x, :y] pair and write to the transform
      x, y = extract_xy(value, type: :scale)
      transform.scale.x = x
      transform.scale.y = y
      transform.scale
    rescue => e
      raise "Cannot update #{self.class.name} scaling_#{method_name} with #{value.class.name}: #{e.message}"
    end
    # Aliasing
    alias_method :"angular_#{method_name}", angular_method_name
    alias_method :"angular_#{method_name}=", :"#{angular_method_name}="
    alias_method :"scaling_#{method_name}", scaling_method_name
    alias_method :"scaling_#{method_name}=", :"#{scaling_method_name}="
    if method_name == :position
      alias_method :"angle_#{method_name}", angular_method_name
      alias_method :"angle_#{method_name}=", :"#{angular_method_name}="
      alias_method :"scale_#{method_name}", scaling_method_name
      alias_method :"scale_#{method_name}=", :"#{scaling_method_name}="
    end
  end

  # Converts a game object into an integration hash format
  def to_integration_hash
    self.transforms.reduce({}){|acc, (component_key, transform)|
      transform.to_integration_hash(component_key).reduce(acc){|acc2, (key, value)|
        acc2[key] = value
        acc2
      }
    }
  end
  def to_integration_hash_slow
    skip_value_fn = lambda{|value|
      case value
      when Hash
        value.all?{|k,v| skip_value_fn.call(v)}
      when Numeric
        value.zero?
      when nil
        true
      else
        false
      end
    }
    self.transforms.reduce({}){|acc, (component_key, transform)|
      if !transform.zero?
        transform.to_integration_hash(component_key).reduce(acc){|acc2, (key, value)|
          acc2[key] = value if !skip_value_fn.call(value)
          acc2
        }
      end
      acc
    }
  end
  # Parses an integration hash into new transforms
  def from_integration_hash(integration_hash)
    transforms_hash = TRANSFORMS.reduce({}){|acc, component_key|
      # puts integration_hash.inspect
      acc[component_key] = Physics::Transform.from_integration_hash(integration_hash, component_key)
      acc
    }
    self.transforms = transforms_hash
  end

  def global_collider
    Physics.apply_transform(self.transforms[:position], self.local_collider)
    # @_last_position ||= {}
    # if @_last_position.keys.size > 1
    #   # Fully replaces, delete cache and start over
    #   @_last_position = {}
    # end
    # transform = self.transforms[:position]
    # transform_data = {
    #   x: transform.position.x,
    #   y: transform.position.y,
    #   a: transform.rotation,
    #   sx: transform.scale.x,
    #   sy: transform.scale.y
    # }
    # @_last_position[transform] ||= transform_data
    # if (@_last_position[transform] != transform_data) || @_last_position[transform].all?{|k, v| transform_data[k] == v}
    #   @_last_position[transform] = transform_data
    #   @global_collider = nil
    # end
    # @global_collider ||= Physics.apply_transform(self.transforms[:position], self.local_collider)
  end
  alias_method :collider, :global_collider

  def scaled_dimensions
    unscaled_w, unscaled_h = self.unscaled_dimensions.values_at(:w, :h)
    scaled_w = self.scale.x * unscaled_w
    scaled_h = self.scale.y * unscaled_h
    {w: scaled_w, h: scaled_h}
  end
  alias_method :dimensions, :scaled_dimensions

  def axis_aligned_bounding_box
    self.global_collider.aabb
  end
  alias_method :aabb, :axis_aligned_bounding_box

  def render_aabb
    # Height and width might have different signs because of how internal calculations work, so need to make those consistent
    aabb_hash = self.aabb
    # aabb_hash = self.local_collider.aabb
    sign_corrected_scaled_dimensions = self.scaled_dimensions.reduce({}){|acc, (dim, value)|
      acc[dim] = value.abs * (aabb_hash[dim] <=> 0)
      acc
    }
    aabb_hash.merge(sign_corrected_scaled_dimensions)
  end

  def angle_anchor
    angle_radians = self.angle.to_radians
    cos_angle_radians = Math.cos(angle_radians)
    sin_angle_radians = Math.sin(angle_radians)
    MathExt::Matrix.multiply([
      [cos_angle_radians, -sin_angle_radians],
      [sin_angle_radians,  cos_angle_radians]
    ], [(62 / 100.0), ((80-55) / 80.0)])
  end

  def to_render_hash
    aabb_hash = self.render_aabb
    {
      path: self.sprite,
      angle: self.angle,
      # anchor_x: (62/100.0),
      # anchor_y: ((80-55)/80.0),
      # angle_anchor_x: (87/100.0),
      # angle_anchor_y: ((80-56)/80.0),
      # angle_anchor_x: ((62 * Math.cos(self.angle.to_radians))/100.0),
      # angle_anchor_y: (((80-55) * Math.sin(self.angle.to_radians))/80.0),
      # angle_anchor_x: Math.cos((self.angle / 180).to_radians),
      # angle_anchor_y: Math.sin((self.angle / 180).to_radians),
      # angle_anchor_x: self.angle_anchor[0],
      # angle_anchor_y: self.angle_anchor[1],
      # flip_horizontally: self.horizontal_flipped?,
      flip_vertically: self.vertical_flipped?,
      **self.render_aabb, # :x, :y, :w, :h
      **self.color # :r, :g, :b, :a
    }#.tap{|h| puts "render_hash: #{h.inspect}"}
  end

  def horizontal_flipped?
    self.scale.x < 0
  end
  def vertical_flipped?
    self.scale.y < 0
  end

  def to_render_debug
    self.to_render_hash.except(:path).merge(r: 0, g: 255, b: 0, a: 50)
  end

  def to_collider_debug
    self.collider.aabb.merge(r: 0, g: 0, b: 255, a: 50, path: "sprites/square/black.png")
  end

  private
    # Helpers for extracting [:x, :y] pairs when setting transform values
    def extract_xy(object, type: nil)
      case object
      when Array
        extract_xy_from_array(object)
      when Hash
        extract_xy_from_hash(object)
      when Physics::Transform::Vector
        extract_xy_from_vector(object, type: type)
      else
        raise "Cannot extract [:x, :y] pair from #{object.class.name} #{object.inspect}"
      end
    end
    def extract_xy_from_array(array)
      # Allow only a position array ([x, y]) or an affine position array ([x, y, 1])
      x, y, rest = value
      if (rest.nil? || rest.is_a?(Numeric)) && value.all?{|v| v.is_a?(Numeric)}
        # Return the position
        [x, y]
      else
        # Raise an error
        raise "Cannot extract [:x, :y] pair from Array #{value.inspect}, must match [:x, :y] | [:x, :y, :z]"
      end
    end
    def extract_xy_from_hash(hash, type: )
      # Must match any of these formats:
      #   {x: Numeric, y: Numeric}
      #   {<linear_method_name>: {x: Numeric, y: Numeric} }
      #   {<linear_method_name>: [x, y] }
      #   {<linear_method_name>: [x, y, z] }
      #   {<linear_method_name>: Physics::Transform::Position}
      #   {<method_name>: {<linear_method_name>: {x: Numeric, y: Numeric} } }
      #   {<method_name>: {<linear_method_name>: [x, y] } }
      #   {<method_name>: {<linear_method_name>: [x, y, z] } }
      #   {<method_name>: {<linear_method_name>: Physics::Transform::Position } }
      extract_keys = [:x, :y]
      xy_pair = [value, value[linear_method_name], value.dig(method_name, linear_method_name)].reduce([]){|acc, comp|
        # Extract the pair
        xy_pair =  (case comp
                    when array
                      extract_xy_from_array(comp)
                    when Hash
                      x, y = comp.values_at(:x, :y)
                      (!x.nil? && !y.nil?) ? [x, y] : nil
                    when Physics::Transform::Vector
                      extract_xy_from_vector(comp, type: type)
                    end)
        # Add the pair if it's not already in the collection
        acc << xy_pair if !xy_pair.nil? && !(acc.include?(xy_pair))
        # Raise an error if there's ever more than one possibility
        raise "Cannot extract [:x, :y] pair from Hash #{value.inspect}, more than one possible pair"
        acc
      }.first

      self.transforms[method_name].position = value
    end
    def extract_xy_from_vector(vector, type: )
      case [type, vector]
      when [:position, Physics::Transform::Position], [:scale, Physics::Transform::Scale]
        value.to_a
      else
        raise "Cannot extract [:x, :y] pair for #{type} from #{vector.class.name} #{vector.inspect}"
      end
    end
end
