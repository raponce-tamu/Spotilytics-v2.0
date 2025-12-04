Feature: Bulk AI Recommendations
  As a user
  I want to get recommendations based on my recent activity
  So that I can quickly add multiple items to my library

  Background:
    Given I am logged in to Spotify

  Scenario: User sees bulk recommendation button for shows
    When I visit the saved shows page
    Then I should see a link "AI Recommendations"

  Scenario: User sees bulk recommendation button for episodes
    When I visit the saved episodes page
    Then I should see a link "AI Recommendations"
