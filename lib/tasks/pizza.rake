require 'pizzaconfig.rb'
require 'pizza_order_helpers.rb'

namespace :db do
  desc "Seed Pizza Page"
  task seed_pizza: :environment do
    pizzapage = Pizzapage.find_or_create_by(PizzaConfig::PIZZAPAGE_PARAMS)
    pizzapage.create_categories_and_products
    cart = Cart.create()
    PizzaConfig::ORDER.each do |product_name, options|
      product = Product.find_by_name(product_name)
      ProductOrder.create(product: product, cart: cart, options: options)
    end
    puts PizzaConfig::ORDER_INFO
    puts PizzaConfig::ORDER
    puts "Please confirm the above information"
    puts "Enter (y) to continue and see cart total"
    answer = STDIN.gets.chomp
    if answer == "y"
      pizza_order = PizzaOrder.new(cart, pizzapage)
      puts pizza_order.cart_total
      puts "Is the above total correct? Enter (y) to checkout"
      confirm = STDIN.gets.chomp
      if confirm == "y"
        pizza_order.proceed_to_checkout
      end
    end
    cart.destroy
  end
end