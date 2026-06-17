module ApplicationHelper
  include Pagy::Frontend

  INPUT_CLASSES = "block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:outline-2 focus:outline-indigo-600".freeze
  PRIMARY_BUTTON_CLASSES = "inline-block cursor-pointer rounded-md bg-indigo-600 px-3.5 py-2.5 text-center font-medium text-white hover:bg-indigo-500".freeze

  def field_error(record, attribute)
    message = record.errors.messages_for(attribute).first
    tag.p(message, class: "mt-1 text-sm text-red-600") if message
  end
end
