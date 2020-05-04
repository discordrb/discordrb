# frozen_string_literal: true

# API calls for Webhook object
module Discordrb::API::Webhook
  module_function

  # Get a webhook
  # https://discord.com/developers/docs/resources/webhook#get-webhook
  def webhook(token, webhook_id)
    Discordrb::API.request(
      :webhooks_wid,
      nil,
      :get,
      "#{Discordrb::API.api_base}/webhooks/#{webhook_id}",
      Authorization: token
    )
  end

  # Get a webhook via webhook token
  # https://discord.com/developers/docs/resources/webhook#get-webhook-with-token
  def token_webhook(webhook_token, webhook_id)
    Discordrb::API.request(
      :webhooks_wid,
      nil,
      :get,
      "#{Discordrb::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}"
    )
  end

  # Update a webhook
  # https://discord.com/developers/docs/resources/webhook#modify-webhook
  def update_webhook(token, webhook_id, data, reason = nil)
    Discordrb::API.request(
      :webhooks_wid,
      webhook_id,
      :patch,
      "#{Discordrb::API.api_base}/webhooks/#{webhook_id}",
      data.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update a webhook via webhook token
  # https://discord.com/developers/docs/resources/webhook#modify-webhook-with-token
  def token_update_webhook(webhook_token, webhook_id, data, reason = nil)
    Discordrb::API.request(
      :webhooks_wid,
      webhook_id,
      :patch,
      "#{Discordrb::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}",
      data.to_json,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Deletes a webhook
  # https://discord.com/developers/docs/resources/webhook#delete-webhook
  def delete_webhook(token, webhook_id, reason = nil)
    Discordrb::API.request(
      :webhooks_wid,
      webhook_id,
      :delete,
      "#{Discordrb::API.api_base}/webhooks/#{webhook_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Deletes a webhook via webhook token
  # https://discord.com/developers/docs/resources/webhook#delete-webhook-with-token
  def token_delete_webhook(webhook_token, webhook_id, reason = nil)
    Discordrb::API.request(
      :webhooks_wid,
      webhook_id,
      :delete,
      "#{Discordrb::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}",
      'X-Audit-Log-Reason': reason
    )
  end
end
