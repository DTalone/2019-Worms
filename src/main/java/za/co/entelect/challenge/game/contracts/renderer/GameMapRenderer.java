package za.co.entelect.challenge.game.contracts.renderer;

import za.co.entelect.challenge.game.contracts.map.GameMap;

public interface GameMapRenderer {

    String render(GameMap gameMap);
}