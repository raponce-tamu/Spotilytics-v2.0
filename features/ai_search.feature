Feature: AI Smart Search
  As a user
  I want to use AI to optimize my search queries
  So that I can find relevant content more easily

  Background:
    Given I am logged in to Spotify

  Scenario: User sees AI search toggle on Saved Shows search page
    When I visit the saved shows search page
    Then I should see a checkbox "AI Search"

  Scenario: User sees AI search toggle on Saved Episodes search page
    When I visit the saved episodes search page
    Then I should see a checkbox "AI Search"
