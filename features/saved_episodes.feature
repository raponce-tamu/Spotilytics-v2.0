Feature: Saved Episodes
  As a user
  I want to manage my saved episodes
  So that I can keep track of episodes I like

  Background:
    Given I am logged in to Spotify

  Scenario: View saved episodes
    Given I have saved episodes
    When I visit the saved episodes page
    Then I should see a list of my saved episodes
    And I should see pagination controls

  Scenario: Search and save an episode
    When I visit the saved episodes page
    And I click "Find New Episodes"
    And I search for "News"
    Then I should see search results for "News"
    When I click "Save to Library" for the first result
    Then I should see "Episode saved to your library"

  Scenario: Remove a saved episode
    Given I have saved episodes
    When I visit the saved episodes page
    And I click "Remove from Library" for the first episode
    Then I should see "Episode removed from your library"

  Scenario: Empty state
    Given I have no saved episodes
    When I visit the saved episodes page
    Then I should see "You haven't saved any episodes yet"
