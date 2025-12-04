Feature: Saved Shows
  As a user
  I want to manage my saved shows
  So that I can keep track of podcasts I like

  Background:
    Given I am logged in to Spotify

  Scenario: View saved shows
    Given I have saved shows
    When I visit the saved shows page
    Then I should see a list of my saved shows
    And I should see pagination controls

  Scenario: Search and save a show
    When I visit the saved shows page
    And I click "Find New Shows"
    And I search for "News"
    Then I should see search results for "News"
    When I click "Save to Library" for the first result
    Then I should see "Show saved to your library"

  Scenario: Remove a saved show
    Given I have saved shows
    When I visit the saved shows page
    And I click "Remove from Library" for the first show
    Then I should see "Show removed from your library"

  Scenario: Empty state
    Given I have no saved shows
    When I visit the saved shows page
    Then I should see "You haven't saved any shows yet"
