class PollVotesController < ApplicationController
  def create
    authorize PollVote

    vote = PollVote.new(user: current_user, choice: params[:choice])
    return head :unprocessable_entity unless vote.save || PollVote.exists?(user: current_user)

    render turbo_stream: turbo_stream.update("poll-popup-body", partial: "poll_votes/results", locals: { tally: PollVote.tally })
  end
end
