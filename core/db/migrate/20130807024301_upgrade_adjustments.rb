class UpgradeAdjustments < ActiveRecord::Migration
  def up
    # Temporarily make originator association available
    Spree::Adjustment.class_eval do
      belongs_to :originator, polymorphic: true
    end
    # Shipping adjustments are now tracked as fields on the object
    add_column :spree_shipments, :adjustment_total, :decimal, :precision => 10, :scale => 2, :default => 0.0
    Spree::Adjustment.where(:source_type => "Spree::Shipment").find_each do |adjustment|
      # Account for possible invalid data
      next if adjustment.source.nil?
      adjustment.source.update_column(:adjustment_total, adjustment.amount)
      adjustment.destroy
    end

    # Tax adjustments have their sources altered
    Spree::Adjustment.where(:originator_type => "Spree::TaxRate").find_each do |adjustment|
      adjustment.source = adjustment.originator
      adjustment.save
    end

    # Promotion adjustments have their source altered also
    Spree::Adjustment.where(:originator_type => "Spree::PromotionAction").find_each do |adjustment|
      next if adjustment.originator.nil?
      adjustment.source = adjustment.originator
      begin
        if adjustment.source.calculator_type == "Spree::Calculator::FreeShipping"
          # Previously this was a Spree::Promotion::Actions::CreateAdjustment
          # And it had a calculator to work out FreeShipping
          # In Spree 2.2, the "calculator" is now the action itself.
          adjustment.source.becomes(Spree::Promotion::Actions::FreeShipping)
        end
      rescue
        # Fail silently. This is primarily in instances where the calculator no longer exists
      end

      adjustment.save
    end
  end
end
