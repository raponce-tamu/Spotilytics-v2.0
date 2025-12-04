Feature: Episode Summary
  As a user
  I want to get a summary of a podcast episode
  So that I can decide if I want to listen to it

  Background:
    Given I am logged in to Spotify
    And I have saved episodes

  Scenario: User sees summarize button
    When I visit the saved episodes page
    Then I should see the AI button "Summarize Episode (AI)"
