# frozen_string_literal: true

require_relative 'background'
require_relative 'storage'
require_relative 'physics'
require_relative 'math_ext'
require_relative 'input'
require_relative 'enemies'
require_relative 'rendering'
require_relative 'game_object'
require_relative 'sfx'

require_relative '/lib/drb-profiling/lib/profiler'

$p = {}
$fps = Profiler.new('Frame timer', 60)
def profile(thing, &block)
  p = $p[thing] ||= Profiler.new(thing.to_s.capitalize, 1000)
  p.profile(&block)
end


module RNG
  class << self
    # TODO: Implement one of the following:
    #   * Quad tree
    #   * R-tree
    #   * Range-tree
    # See:
    #   https://0fps.net/2015/01/18/collision-detection-part-2/
    #   https://0fps.net/2015/01/23/collision-detection-part-3-benchmarks/
    #   https://github.com/mikolalysenko/box-intersect
    def enemy_position(grid, game_objects, w: , h: )
      candidate_x = rand(grid.w * 0.4) + (grid.w * 0.6) - w
      candidate_y = rand(grid.h - h * 2) + h
      game_objects ||= []
      has_intersection = game_objects.any?{|game_object|
        Geometry.intersect_rect?(
          game_object.aabb,
          {x: candidate_x, y: candidate_y, w: w, h: h}
        )
      }
      return self.enemy_position(grid, game_objects, w: w, h: h) if has_intersection
      [candidate_x, candidate_y]
    end
  end
end

module Window
  class << self
    def clamp_to_grid(grid, game_object)
      # # Clamp left/right
      # obj_hash[:position][:x] = obj_hash.dig(:position, :x).clamp(0, grid.w - obj_hash.dig(:scale, :w))
      # # Clamp bottom/top
      # obj_hash[:position][:y] = obj_hash.dig(:position, :y).clamp(0, grid.h - obj_hash.dig(:scale, :h))
      # puts "obj_hash position#{obj_hash.transforms.position.scale.inspect}"

      # x_val = obj_hash[:transforms][:position].position.x
      # y_val = obj_hash[:transforms][:position].position.y
      # w_val = obj_hash.dig(:dimensions, :w) * obj_hash[:transforms][:position].scale.x
      # h_val = obj_hash.dig(:dimensions, :h) * obj_hash[:transforms][:position].scale.y
      # # Clamp left/right
      # obj_hash[:transforms][:position]&.position&.send(:x=, x_val.clamp(0, grid.w - w_val))
      # # Clamp bottom/top
      # obj_hash[:transforms][:position]&.position&.send(:y=, y_val.clamp(0, grid.h - h_val))

      # obj_hash

      x_val = game_object.position.x
      y_val = game_object.position.y
      w_val = game_object.dimensions.w
      h_val = game_object.dimensions.h
      # Clamp left/right
      game_object.position.x = x_val.clamp(0, grid.w - w_val)
      # Clamp bottom/top
      game_object.position.y = y_val.clamp(0, grid.h - h_val)

      game_object
    end

    def offscreen?(grid, game_object, padding: {w: 0, h: 0})
      x = game_object.position.x
      y = game_object.position.y
      w_right = grid.w + (padding.w / 2.0)
      w_left = -(padding.w / 2.0)
      h_top = grid.h + (padding.h / 2.0)
      h_bot = -(padding.h / 2.0)

      (x > w_right) || (x < w_left) || (y > h_top) || (y < h_bot)
    end
  end
end

FPS = 60
SAVE_FILE = 'save.json'

# Why can we read JSON but not write it?
def serialize_json(obj)
  case obj
  when Hash
    inner = obj.map{|k,v| "\"#{k}\": #{serialize_json(v)}"}.join(',')
    "{#{inner}}"
  when Array
    inner = obj.map{|v| serialize_json(v)}.join(',')
    "[#{inner}]"
  else
    obj.respond_to?(:to_json) ? obj.to_json : obj.respond_to?(:as_json) ? serialize_json(obj.as_json) : obj.respond_to?(:to_s) ? obj.to_s : obj
  end
end

def save(file, hash)
  $gtk.write_file(file, serialize_json(hash))
end
def load(file, default: nil)
  $gtk.stat_file(file).nil? ? default : $gtk.parse_json_file(file) || default
end

def mute(args)
  args.audio[:music] = nil
  args.outputs.sounds = []
end

def create_explosion(args, fireball, target)
  {
    # Average the collider :x, :y coords, and center the explosion
    x: ((fireball.collider.center[0] + target.collider.center[0]) / 2.0) - 16,
    y: ((fireball.collider.center[1] + target.collider.center[1]) / 2.0) - 16,
    w: 32,
    h: 32,
    data: {
      tick_count: args.state.tick_count,
      delta_angle: lambda{
        angle_opt = MathExt.weighted_random_select([
          {weight: 1, range: -24..24},
          {weight: 16, range: -20..20},
          {weight: 32, range: -16..16},
          {weight: 64, range: -12..12},
          {weight: 128, range: -8..8},
          {weight: 256, range: -5..5},
          {weight: 512, value: 0}
        ])
        angle_opt[:value] || rand(angle_opt[:range].max - angle_opt[:range].min) + angle_opt[:range].min
      }.call()
    },
    angle: rand(360),
    flip_horizontally: rand() < 0.5,
    flip_vertically: rand() < 0.5,
    source_x: 0,
    source_y: 0,
    source_w: 32,
    source_h: 32,
    path: "sprites/misc/explosion-sheet.png"
    # path: "sprites/misc/explosion-3.png"
  }
end

def create_player
  GameObject.new({
    transforms: {
      position: {
        position: {x: 120, y: 280},
        angle_position: {theta: 0},
        scale_position: {x: 1, y: 1}
      }
    },
    dimensions: {
      w: 100,
      h: 80,
    },
    data: {
      speed: 10,
      animation: {
        # anim_coeff: 1,
        start_tick: 0,
        prev_hold: 0,
        # prev_hold_mult: 1,
        prev_offset: 0,
        prev_hold_mult: 1,
        count: 6,
        hold_for: 8
        # hold_for: 100
      }
    },
    collider: Physics::Colliders.aabb({x: 0, y: 0, w: 100, h: 80}, relative_to: {x: 62, y: (80 - 55)}),
    sprite: 'sprites/misc/dragon-0.png'
  })
end

def animate_player(player, player_input_info)
  start_tick = player.data.animation.start_tick
  prev_offset = player.data.animation.prev_offset
  prev_hold_mult = player.data.animation.prev_hold_mult
  count = player.data.animation.count
  hold_for = player.data.animation.hold_for
  # We want the hold multipliers to be between 0.75 (flapping faster) and 1.25 (flapping slower) for vertical movement, and between 1 and 1.15 (flapping slower) for horizontal movement
  # The movement variables for horizontal and vertical movement are between -1 and 1, where we want to flap:
  #   +Vertical: Faster
  #   -Vertical: Slower
  #   +Horizontal: Faster
  #   -Horizontal: Faster
  vertical_mod_sign = -(player_input_info.movement.vertical <=> 0) # Up (+) is faster, so need to flip the sign
  vertical_hold_mult = 1 + (vertical_mod_sign * MathExt.change_linear_scales(player_input_info.movement.vertical.abs, 0..1, [0, 0.5]))
  # Horizontal is similar, but we can ignore the sign
  horizontal_hold_mult = 1 - MathExt.change_linear_scales(player_input_info.movement.horizontal.abs, 0..1, [0, 0.25])
  hold_mult = vertical_hold_mult * horizontal_hold_mult

  # We want to maintain the same frame and the same number of ticks to the next frame, so it's ok to calculate the current frame here
  total_hold_for = (hold_for * prev_hold_mult)
  current_frame = (start_tick - prev_offset).frame_index(count: count, hold_for: total_hold_for, repeat: true)

  # Check for whether or not we need to change the animation speed, and if so calculate what the next offset should be so that the animation is smooth
  if hold_mult != prev_hold_mult
    # We need to know a little bit about how Numeric#frame_index works first in order to predict how it resolves next tick. Basically it takes the current elapsed time relative to the number you pass to frame index, then calculates the frame based off that. There would be some extra math depending on whether or not there's a different repeat point in the animation, or if we're blending between animations, but because we aren't we can skip that.
    # In general, the process we need to take is to determine the remaining ticks before the next animation frame, then scale that to the new animation length to determine the new scaled remaining ticks.
    #
    # See:
    #   https://github.com/DragonRuby/dragonruby-game-toolkit-contrib/blob/f267f6618055b9df90fed5d212c6c82ddaee527b/dragon/numeric.rb#L176-L197
    #   https://github.com/DragonRuby/dragonruby-game-toolkit-contrib/blob/f267f6618055b9df90fed5d212c6c82ddaee527b/dragon/numeric.rb#L123-L174
    #   https://github.com/DragonRuby/dragonruby-game-toolkit-contrib/blob/f267f6618055b9df90fed5d212c6c82ddaee527b/dragon/numeric.rb#L94-L121
    #   https://github.com/DragonRuby/dragonruby-game-toolkit-contrib/blob/f267f6618055b9df90fed5d212c6c82ddaee527b/dragon/numeric.rb#L75-L77
    #   https://github.com/DragonRuby/dragonruby-game-toolkit-contrib/blob/f267f6618055b9df90fed5d212c6c82ddaee527b/dragon/numeric.rb#L427-L430

    # Obtain the currently elapsed ticks and figure out the current remaining tick count
    elapsed_ticks = (start_tick - prev_offset).elapsed_time()
    next_frame = current_frame + 1
    remaining_tick_count = ((next_frame - current_frame) * total_hold_for * count) - (elapsed_ticks % (count * total_hold_for))

    # Next, determine the animation lengths for the current and next animation so we can scale the remaining ticks
    next_total_hold_for = (hold_for * hold_mult)
    current_anim_length = count * total_hold_for
    next_anim_length = count * next_total_hold_for

    # Scale the remaining ticks, then calculate the next offset
    next_remaining_tick_count = MathExt.change_linear_scales(remaining_tick_count, 0..current_anim_length, 0..next_anim_length)
    next_offset = next_anim_length - next_remaining_tick_count

    # Update the start tick, offset, and hold multiplier
    player.data.animation.start_tick = Kernel.tick_count
    player.data.animation.prev_offset = next_offset
    player.data.animation.prev_hold_mult = hold_mult
  end

  # Find and set the correct sprite
  player.sprite = "sprites/misc/dragon-#{current_frame}.png"
end

# Left Off:
#   https://book.dragonriders.community/04-target-practice.html#extra-credit

SCENES = {
  title: :title_tick,
  level: :level_tick,
  game_over: :game_over_tick
}

def tick(args)
  $fps.profile_between_calls
  args.state.timer ||= Float::INFINITY
  args.state.current_scene ||= :title
  # Process any crossfades
  SFX.process_crossfade(args.audio, :music, 0.01)

  # Countdown
  if args.state.timer == 0
    # Stop the music and play SFX
    args.audio[:music].paused = true
    args.outputs.sounds << SFX.game_over
  elsif args.state.timer < 0
    args.state.current_scene = :game_over
    return
  end

  scene_method = SCENES[args.state.current_scene]
  self.send(scene_method, args)
end

def title_tick(args)
  # Start the title music
  SFX.start_or_crossfade_music(args.audio, :music, SFX.title_bgm)
  # Preview the player
  args.state.player ||= create_player()
  animate_player(args.state.player, {movement: {vertical: 0, horizontal: 0}})
  # Check for game start
  if Input.is_firing?(args.inputs)
    args.outputs.sounds << SFX.start_game
    args.state.current_scene = :level
    level_tick(args)
    return
  end
  # Render
  args.outputs.solids << Background.sky(args.grid)
  args.outputs.sprites << [
    Rendering.player_state_to_sprite_output(args.state.player)
  ]
  args.outputs.labels << [
    # Title + Intro
    {
      x: (args.grid.w / 2.0) - 94,
      y: args.grid.h - 40,
      text: "Draco Builder",
      size_enum: 6
    },
    {
      x: (args.grid.w / 2.0) - 235,
      y: args.grid.h - 80,
      text: "Shoot the enemies, dodge the bullets, build your hoard",
      size_enum: -1
    },
    {
      x: (args.grid.w / 2.0) -220,
      y: args.grid.h - 120,
      text: "Developed by Patrick for the Kifass 2 Game Jam"
    },
    # Controls
    Input.keyboard_controls_info(args.grid).map{|label|
      label.y += 75
      label
    },
    Input.gamepad_controls_info(args.grid).map{|label|
      label.y -= 75
      label
    },
    # Start
    {
      x: (args.grid.w / 2.0) - 72,
      y: 80,
      text: "Fire to start",
      size_enum: 2
    }
  ]
end

def game_over_tick(args)
  # Load the high score, then write a new high score if it's above the current score
  args.state.loaded_save ||= load(SAVE_FILE, default: {'high_scores' => []})
  args.state.last_high_score ||= args.state.loaded_save['high_scores'].first || {'score' => -1}
  if !args.state.saved_high_score && (args.state.score > args.state.last_high_score['score'])
    args.state.loaded_save['high_scores'] = args.state.loaded_save['high_scores'].unshift({
      'score' => args.state.score,
      'unix_time' => Time.now.to_i
    }).take(10)
    save(SAVE_FILE, args.state.loaded_save)
    args.state.last_high_score = args.state.last_high_score
    args.state.saved_high_score = true
  end

  args.outputs.solids << Background.sky(args.grid)
  args.outputs.labels << [
    {
      x: 40,
      y: args.grid.h - 40,
      text: "Game Over!",
      size_enum: 10
    },
    {
      x: 40,
      y: args.grid.h - 90,
      text: "Score: #{args.state.score}",
      size_enum: 4
    },
    {
      x: 260,
      y: args.grid.h - 90,
      text: args.state.saved_high_score ? "New high-score!" : "Score to beat: #{args.state.last_high_score['score']} (#{Time.at(args.state.last_high_score['unix_time'])})",
      size_enum: 3
    },
    *args.state.loaded_save['high_scores'].each_with_index.map{|high_score, idx|
      {
        x: 360,
        y: args.grid.h - (180 + 42 * idx),
        text: "#{high_score['score']} (#{Time.at(high_score['unix_time'])})",
        size_enum: 2
      }
    },
    {
      x: 40,
      y: args.grid.h - 132,
      text: "Fire to restart",
      size_enum: 2
    }
  ]

  Input.handle_restart_input(args.inputs, args.state.player, args.state.fireballs) if args.state.timer < -30
end

def init_level_tick(args)
  # Start the music
  SFX.start_or_crossfade_music(args.audio, :music, SFX.gameplay_bgm)
  # Initialization
  args.state.player ||= create_player()
  args.state.fireballs ||= []
  args.state.targets ||= [].tap{|arr|
    3.times.each{
      arr << Enemies.target(
        *RNG.enemy_position(args.grid, arr, w: 64, h: 64)
      )
    }
  }
  args.state.explosions ||= []
  args.state.score ||= 0
  args.state.timer = nil if args.state.timer == Float::INFINITY
  args.state.timer ||= 30 * FPS * (2 * 6000)
  args.state.timer -= 1
end

# Spawn limits (of moving GameObjects) with an additional 4 non-moving GameObjects while maintaining ~60 FPS on average:
#   * Fireballs: 88
# Constant spawning limits maximum:
#   * Player
#     - Fireballs: 54
def level_tick(args)
  # Initialize
  init_level_tick(args)

  # Input handling
  Input.handle_input(args.inputs, args.state.player, args.state.fireballs, args.outputs.sounds){|player_input_info|
    animate_player(args.state.player, player_input_info)
  }

  # Physics
  profile(:motion) do # 2nd place in inefficiency (~21.3ms per tick @ 200 fireballs)
    # Physics.motion(args.state.player)
    args.state.fireballs.each{|fireball|
      # Move
      Physics.motion(fireball)
      # Animate
      fireball_sprite_index = fireball.data.start_tick.frame_index(count: 2, hold_for: 4, repeat: true)
      fireball.sprite = "sprites/misc/fireball-#{fireball_sprite_index}.png"
      # Cleanup
      fireball.data.delete = true if Window.offscreen?(args.grid, fireball)
    }
  end


  # profile(:collisions) do # 1st place in inefficiency (~30ms per tick @ 200 fireballs)
    Physics.handle_collisions(args.state.fireballs, args.state.targets){|fireball, target|
      profile(:collisions_block_call) do
        # Play SFX
        args.outputs.sounds << SFX.target_destroyed
        # Mark the fireball and target for deletion
        fireball.data.delete = true
        target.data.delete = true
        # Add an explosion animation
        args.state.explosions << create_explosion(args, fireball, target)
        # Increment score
        args.state.score += 1
        # Build new target
        args.state.targets << Enemies.target(
          *RNG.enemy_position(
            args.grid,
            [*args.state.targets, *args.state.fireballs],
            w: target.dimensions.w,
            h: target.dimensions.h
          )
        ) if args.state.targets.size < 4
      end
    }
  # end

  # Animate explosions
  args.state.explosions.each{|explosion|
    # Audio is 0.325 seconds (325 ms), each frame is 1000/60 ms, and there are 7 frames of animation. So the animation time per frame is (325 / (1000/60) / 7) == (325 * 60) / 7000
    frame_index = explosion.data.tick_count.frame_index(count: 7, hold_for: ((325 * 60) / 7000.0))
    if frame_index.nil? # Remove the explosion
      explosion.data[:delete] = true
    else # Update the animation
      explosion.angle += explosion.data.delta_angle
      explosion.source_x = explosion.source_w * frame_index
    end
  }

  # Cleanup
  # profile(:cleanup) do # Irrelevant
    args.state.fireballs.reject!{|fireball| fireball.data[:delete]}
    args.state.targets.reject!{|target| target.data[:delete]}
    args.state.explosions.reject!{|explosion| explosion.data[:delete]}
  # end

  # Ensure requirements
  # profile(:clamp_to_grid) do # Irrelevant
    Window.clamp_to_grid(args.grid, args.state.player)
  # end

  # Rendering
  # TODO: If this can render thousands of objects being constantly recreated, why is adding ~40 fireballs so heavy???
  profile(:solids) do
    args.outputs.solids << Background.sky(args.grid)
  end
  profile(:sprites) do # 3rd place in inefficiency (~16.4ms per tick @ 200 fireballs)
    args.outputs.sprites << [
      Rendering.player_state_to_sprite_output(args.state.player),
      Rendering.fireballs_state_to_sprite_output(args.state.fireballs),
      Rendering.targets_state_to_sprite_output(args.state.targets),
      args.state.explosions,
      args.state.player.to_collider_debug,
    ]
  end
  # UI Panels
  args.outputs.solids << [
    # args.state.player.to_solid_debug,
    # args.state.player.to_collider_debug,
    {
      # Score background ("Score:" is size 80w x 28h, we want some padding as well though)
      x: 30,
      y: args.grid.h - 30,
      w: 260,
      h: -48,
      r: 255, g: 255, b: 255, a: 75
    },
    {
      # Timer background
      x: args.grid.w - 30,
      y: args.grid.h - 30,
      w: -220,
      h: -43,
      r: 255, g: 255, b: 255, a: 75
    }
  ]
  # UI Text
  args.outputs.labels << [
    {
      x: 40,
      y: args.grid.h - 40,
      text: "Score: #{args.state.score}",
      size_enum: 4
    },
    {
      x: args.grid.w - 40,
      y: args.grid.h - 40,
      text: "Time Left: #{(args.state.timer / FPS).round}",
      size_enum: 2,
      alignment_enum: 2
    }
  ]

  # Debug
  prof_y = 630
  args.outputs.debug << [
    {
      x: 40,
      y: args.grid.h - 80,
      text: "Fireballs: #{args.state.fireballs.size}"
    }.label!,
    {
      x: 40,
      y: args.grid.h - 100,
      text: "1st fireball x pos: #{args.state.fireballs[0]&.position&.x}"
    }.label!,
    # args.gtk.framerate_diagnostics_primitives
    { x: 8, y: 720 - 38, text: $fps.report },
    { x: 8, y: 720 - 8, text: Profiler.metaprofiler.report },

  ]
  $p.sort_by { |k, p| -p.avg_time }.each{|k, p|
    args.outputs.debug << { x: 8, y: prof_y, text: p.report }
    prof_y -= 30
  }
  # mute(args)
  # Evening Melodrama
end


$gtk.reset
