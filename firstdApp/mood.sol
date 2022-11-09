// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.1;

/**
* @title MoodTracker
* @author Ryan Kausin
* @dev MoodTracker is a simple smart contract that allows one to 
* set their mood and get their mood on the blockchain
*/
 contract MoodTracker {
     string mood;

     /**
     * @param _mood writes a mood to the smart contract
     */
     function setMood(string memory _mood) public {
        mood = _mood;
    }
     /**
     * @return the smart contract mood
     */
      function getMood() public view returns(string memory) {
          return mood;
      }
 }