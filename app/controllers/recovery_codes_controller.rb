# frozen_string_literal: true

# Your recovery codes: how many are left, which have been spent, and a way to
# replace the set. The codes themselves are shown once, at the moment they are
# generated, and never again - only their digests are kept.
class RecoveryCodesController < ApplicationController
  def show
    @codes = current_user.recovery_codes.ordered
    @fresh = flash[:fresh_recovery_codes]
  end

  def create
    if current_user.email.blank?
      return redirect_to edit_email_path,
                         alert: "Add an email first - recovery codes are redeemed against it."
    end

    result = RecoveryCodeIssuer.call(user: current_user, actor: current_user)
    flash[:fresh_recovery_codes] = result.codes
    redirect_to recovery_codes_path, notice: "New codes generated."
  end
end
