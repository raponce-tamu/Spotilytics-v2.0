Feature: Group Episodes
  As a user
  I want to group my saved episodes by show
  So that I can organize my library better

  Background:
    Given I am logged in to Spotify

  Scenario: User sees group by show button
    When I visit the saved episodes page
    Then I should see a link "Group by Show"
