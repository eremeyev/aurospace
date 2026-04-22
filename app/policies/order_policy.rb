# frozen)string_literal: true
class OrderPolicy
   def purchase? = record.pending?
   def cancel?   = record.success?
end
