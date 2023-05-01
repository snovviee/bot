require_relative 'account'

Account.new(
  market: {
    api_key: 'x3FVZ51Ob9CKC3X07f2T94GfAK92PKT'
  },
  dmarket: {
    api_key: '4faf64741c387d3eec26f1a8262f2f18b43a5db7c2a816efc71cc4fa4b54863d',
    secret_key: 'e7c964f093083a94e71ab083835544684d95f22520061c42315af5708de8152b4faf64741c387d3eec26f1a8262f2f18b43a5db7c2a816efc71cc4fa4b54863d'
  },
  steam: {
    username: 'topsnovvieeua',
    password: 'Chakbass19',
    shared_secret: 'fvl4gMLRlOgS4pDOKM0uulPX9lE=',
    identity_secret: 'uGMQI5Ap26n4R9pbLRUNsTHpTIk='
  }
)

Account.all.each { |acc| Thread.new { acc.withdraw! } }
Account.all.each { |acc| acc.accept_offers! }
