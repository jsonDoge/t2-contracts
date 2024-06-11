// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

library Utils {
  
    enum Season { Winter, Spring, Summer, Autumn }

    function getHasGrowthSeason(Season s, uint8 plantGrowthSeasons) public pure returns (bool) {
        if (s == Season.Winter) {
            return plantGrowthSeasons & 0x1 > 0;
        } else if (s == Season.Spring) {
            return plantGrowthSeasons & 0x2 > 0;
        } else if (s == Season.Summer) {
            return plantGrowthSeasons & 0x4 > 0;
        } else if (s == Season.Autumn) {
            return plantGrowthSeasons & 0x8 > 0;
        }

        return false;
    }

    function getCurrentSeason(uint256 blockNumber, uint256 seasonDuration) public pure returns (Season) {
        uint256 modBlockNumber = blockNumber % (4 * seasonDuration);
    
        if (modBlockNumber / seasonDuration < 1) {
            return Season.Winter;
        } else if (modBlockNumber / (seasonDuration * 2) < 2) {
            return Season.Spring;
        } else if (modBlockNumber / (seasonDuration * 3) < 3) {
            return Season.Summer;
        }
    
        return Season.Autumn;
    }
  
    function getCoordinates(uint256 plotId, uint256 maxX) public pure returns (uint256 x, uint256 y) {
        return (plotId % maxX, plotId / maxX);
    }

    function getUpperPlotId(uint256 plotId, uint256 maxX) public pure returns (uint256) {
        return plotId + maxX;
    }

    function getRightPlotId(uint256 plotId) public pure returns (uint256) {
        return plotId + 1;
    }

    function getLowerPlotId(uint256 plotId, uint256 maxX) public pure returns (uint256) {
        return plotId - maxX;
    }

    function getLeftPlotId(uint256 plotId) public pure returns (uint256) {
        return plotId - 1;
    }

    function getPlotIdFromCoordinates(uint256 x, uint256 y, uint256 maxX) public pure returns (uint256 plotId) {
        return x + y * maxX;
    }
}