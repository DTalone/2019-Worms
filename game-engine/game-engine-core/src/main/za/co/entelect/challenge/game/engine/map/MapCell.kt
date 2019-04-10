package za.co.entelect.challenge.game.engine.map

import za.co.entelect.challenge.game.engine.player.Worm
import za.co.entelect.challenge.game.engine.powerups.Powerup
import kotlin.jvm.Transient

class MapCell(var x: Int = -1,
              var y: Int = -1,
              var type: CellType = CellType.AIR) {

    constructor(cellType: CellType = CellType.AIR) : this(type = cellType)

    @Transient var occupier: Worm? = null
    val occupierId // For Renderer
        get() = occupier?.id
    var powerup: Powerup? = null

    @Transient
    val nearCells = NearCells()

    @Transient
    val ipInfo = ImageProcessingInfo()

    val position get() = Point(x, y)

    fun isOccupied(): Boolean {
        return occupier != null
    }

    override fun toString(): String {
        return "MapCell(x=$x, y=$y, type=$type)"
    }

    companion object {
        val comparator: Comparator<MapCell> = compareBy<MapCell> { it.y }.thenBy { it.x }
    }

}