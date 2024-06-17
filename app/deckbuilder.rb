# frozen_string_literal: true

module Deckbuilder
  # Need to be able to set/update the following:
  #   * shield slots
  #   * improve shield value (of last shield)
  #   * improve shield max absorb (of last shield)
  #   * improve attack damage
  #   * improve attack fire rate
  #   * increase attack size
  #   * increase attack retention timer
  #   * increase attack secondary effect timer
  #   * change secondary effect
  #   * heal shield
  #   * change primary attack
  #   * change secondary attack
  #   *
  # Additional effects:
  #   * draw card(s)
  #   * discard
  #   * exhaust card(s)
  #   *
  #
  # Card format:
  # {
  #   attack: {v: <attack_value>},
  #   shield_1: {v: , absorbed: },
  #   shield_2: ,
  #   shield_3: ,
  # }
  CARDS = {
    # Dovahkin!!!
    # https://elderscrolls.fandom.com/wiki/Dragon_Shouts
    fus: {}, # Unrelenting force # YES
    fus_ro: {},
    fus_ro_dah: {},
    raan: {}, # Animal Allegiance # NO
    raan_mir: {},
    raan_mir_tah: {},
    feim: {}, # Become Ethereal # YES
    feim_zii: {},
    feim_zii_gron: {},
    gol: {}, # Bend Will # NO
    gol_hah_dov: {},
    od: {}, # Call Dragon # NO
    od_ah: {},
    od_ah_viing: {},
    ven: {}, # Cyclone # YES
    ven_gaar: {},
    ven_gaar_nos: {},
    mul: {}, # Dragon Aspect (basically just increase stats) # YES
    mul_qah: {},
    mul_qah_diiv: {},
    gaan: {}, # Drain Vitality # YES
    gaan_lah: {},
    gaan_lah_haas: {},
    su: {}, # Elemental Fury (increase speed and rate of fire) # YES
    su_grah: {},
    su_grah_dun: {},
    yol: {}, # Fire Breath # YES
    yol_toor: {},
    yol_toor_shul: {},
    fo: {}, # Frost Breath # YES
    fo_krah: {},
    fo_krah_diin: {},
    iiz: {}, # Ice Form (freezes an enemy) # MAYBE
    iiz_slen: {},
    iiz_slen_nus: {},
    krii: {}, # Marked for Death (cut enemy max hp and shields) # MAYBE
    krii_lun: {},
    krii_lun_aus: {},
    rii: {}, # Soul Tear (killed enemies rise as allies) # NO
    rii_vaaz: {},
    rii_vaaz_zol: {},
    tiid: {}, # Slow Time (everything else slows down) # NO
    tiid_klo: {},
    tiid_klo_ul: {},
    strun: {}, # Storm Call (lightning environmental damage) # MAYBE
    strun_bah: {},
    strun_bah_qo: {},
    wuld: {}, # Whirlwind Sprint ("blink" dash) # YES
    wuld_nah: {},
    wuld_nah_kest: {},
  }
  class << self
    def candidate_rewards(count, potential_cards = CARDS)
      potential_cards.shuffle.take(count)
    end
    def resolve(card)
    end
  end

  module DeckHandDiscard
    class << self
      def initial_deck
        card_counts = {
          spit_fire: 5,
          scales: 5,
          fus: 2,
        }
        card_counts.reduce([]){|deck, (card_key, card_count)|
          card_count.times.each{|_|
            deck << ::Deckbuilder::CARDS[card_key]
          }
          deck
        }
      end

      # Deck/Hand/Discard play
      def initial_deck_hand_discard
        {
          deck: self.initial_deck,
          hand: [],
          discard: []
        }
      end

      ################
      # Deck Updates #
      ################
      def add_cards(deck_hand_discard, *cards)
        card_idxs.flatten!
        # Early exit
        return deck_hand_discard if card_idxs.empty?
        # Construct a new deck/hand/discard representation
        {
          deck: (deck_hand_discard[:deck] + cards).shuffle,
          hand: deck_hand_discard[:hand],
          discard: deck_hand_discard[:discard]
        }
      end
      def remove_cards(deck_hand_discard, *card_idxs)
        card_idxs.flatten!
        # Early exit
        return deck_hand_discard if card_idxs.empty?
        # Construct a new deck/hand/discard representation
        {
          deck: deck_hand_discard[:deck].each_with_index.reject{|card, idx| card_idxs.include?(idx)},
          hand: deck_hand_discard[:hand],
          discard: deck_hand_discard[:discard]
        }
      end

      #############
      # Deck Play #
      #############
      # Draws, plays, discards, and shuffles should never modify the passed in deck/hand/discard representation. Doing so could result in hard to debug issues, and this should happen infrequently enough relative to the rest of the game that the memory cost shouldn't be an issue.
      def draw(deck_hand_discard, card_count, reshuffled: false)
        # Early exit
        return deck_hand_discard if card_count <= 0
        # Attempt drawing the required cards first
        deck_rev = deck_hand_discard[:deck].reverse # Copies the current deck in reverse order
        without_shuffle_cards = deck_rev.slice!(0, card_count) # Takes card_count, modifying deck_rev
        partial_deck_hand_discard = {
          deck: deck_rev.reverse, # Switch the deck back into the correct order
          hand: deck_hand_discard[:hand] + without_shuffle_cards, # Add cards to the hand
          discard: deck_hand_discard[:discard] # Maintain discard
        }
        # Attempt reshuffling and drawing up to the card limit if we couldn't draw enough cards, skipping if we've already reshuffled or it otherwise isn't possible
        remainder = [card_count - without_shuffle_cards.size, 0].max
        if (remainder > 0) && !reshuffled && (without_shuffle_cards.size < card_count) && (partial_deck_hand_discard[:discard].size > 0)
          # Shuffle the discard back into the deck and try again
          reshuffled_deck_hand_discard = self.shuffle(partial_deck_hand_discard)
          return self.draw(reshuffled_deck_hand_discard, remainder, reshuffled: true)
        else
          # Return what we already have, regardless of whether the requested draw count was fulfilled or not (if not there's not enough cards to fulfill it)
          return partial_deck_hand_discard
        end
      end
      def play(deck_hand_discard, *card_idxs)
        card_idxs.flatten!
        # Early exit
        return deck_hand_discard if card_idxs.empty?
        # Find which cards are played and the remaining hand
        changes = deck_hand_discard[:hand].each_with_index.reduce({hand: [], play: []}){|acc, (card, idx)|
          if card_idxs.include?(idx)
            acc[:play] << card
          else
            acc[:hand] << card
          end
        }
        # Resolve the effects of each card
        changes[:play].each{|card| Deckbuilder.resolve(card) }
        # Construct a new deck/hand/discard representation
        {
          deck: deck_hand_discard[:deck],
          hand: changes[:hand]
          discard: deck_hand_discard[:discard] + changes[:play]
        }
      end
      def discard(deck_hand_discard, *card_idxs)
        card_idxs.flatten!
        # Early exit
        return deck_hand_discard if card_idxs.empty?
        # Find which cards are discarded and the remaining hand
        changes = deck_hand_discard[:hand].each_with_index.reduce({hand: [], discard: []}){|acc, (card, idx)|
          if card_idxs.include?(idx)
            acc[:discard] << card
          else
            acc[:hand] << card
          end
        }
        # Construct a new deck/hand/discard representation
        {
          deck: deck_hand_discard[:deck],
          hand: changes[:hand]
          discard: deck_hand_discard[:discard] + changes[:discard]
        }
      end
      def shuffle(deck_hand_discard)
        # Construct a new deck/hand/discard representation, making sure that discard and deck piles are added to prevent card loss in the possible case where a shuffle is requested before the deck is empty
        {
          deck: (deck_hand_discard[:discard] + deck_hand_discard[:deck]).shuffle,
          hand: deck_hand_discard[:hand],
          discard: []
        }
      end
    end
  end
end