# app/policies/order_policy.rb
class OrderPolicy < ApplicationPolicy
   def purchase? = record.pending?
   def cancel?   = record.success?
end