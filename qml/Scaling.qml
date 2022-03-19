import QtQuick 2.3
import QtQuick.Window 2.2

QtObject {
  /* default screen size to scale (14" 1080p) */
  property double defaultWidthPx: 1920
  property double defaultWidthMM: 310
  property double defaultHeightPx: 1080
  property double defaultHeightMM: 174

  /* average of pixels per mm by height and width of default screen size */
  property double defaultPixelDensity: {
    0.5 * (defaultWidthPx/defaultWidthMM + defaultHeightPx/defaultHeightMM)
  }

  /* larger values means a physically smaller screen for the same pixel size */
  property double scalePixelDensity: Screen.pixelDensity / defaultPixelDensity

  /* scale based on screen size and optional command-line arg */
  property double scale: scalePixelDensity * controller.getFontScale()

  property int fontHuge:   scale * 20
  property int fontLarge:  scale * 18
  property int fontMedium: scale * 16
  property int fontSmall:  scale * 14
  property int fontTiny:   scale * 12
}
