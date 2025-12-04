When('I visit the saved shows search page') do
  visit search_saved_shows_path
end

When('I visit the saved episodes search page') do
  visit search_saved_episodes_path
end

Then('I should see a checkbox {string}') do |label|
  expect(page).to have_field(label, type: 'checkbox')
end



Then('I should see the AI button {string}') do |label|
  # Check for button/link with text OR element with title attribute
  found = page.has_selector?(:link_or_button, label) || page.has_css?("[title='#{label}']")
  expect(found).to be(true)
end



Then('I should see a link {string}') do |label|
  expect(page).to have_link(label)
end
