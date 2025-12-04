Feature: Show Recommendations
  As a user
  I want to get insights and similar suggestions for my saved shows
  So that I can discover new content

  Background:
    Given I am logged in to Spotify
    And I have saved shows

  Scenario: View recommendations successfully
    And Spotify returns recommendation data
    When I visit the recommendations page
    Then I should see recommendation cards

  Scenario: Recommendations require login when unauthorized
    And Spotify top APIs raise unauthorized for recommendations
    When I visit the recommendations page
    Then I should be redirected home with message "You must log in with spotify to view your recommendations."

  Scenario: Recommendations show an error when search fails
    And Spotify recommendations search fails with "service failure"
    When I visit the recommendations page
    Then I should see the recommendations error "Failed to fetch recommendations: service failure"

  Scenario: Create playlist from recommendations
    And Spotify returns recommendation data
    When I visit the recommendations page
    And I click "Create playlist"
    And I should see "Playlist created on Spotify"
    
  Scenario: User sees recommendation buttons
    When I visit the saved shows page
    Then I should see the AI button "Why?"
    And I should see the AI button "Similar"
