module Admin
  class PollResultsController < Admin::ApplicationController
    def show
      authorize :admin, :index?
      @tally = PollVote.tally
    end
  end
end
