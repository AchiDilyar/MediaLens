"""Write installer window metadata directly; never drive Finder."""
from pathlib import Path
import sys
from ds_store import DSStore
from mac_alias import Alias

volume = Path(sys.argv[1])
background = volume / '.background' / 'installer.png'
with DSStore.open(str(volume / '.DS_Store'), 'w+') as store:
    store['.']['bwsp'] = {
        'WindowBounds': '{{200, 160}, {760, 560}}',
        'PreviewPaneVisibility': False, 'SidebarWidth': 180,
        'ShowToolbar': False, 'ShowSidebar': False,
        'ShowStatusBar': False, 'ShowPathbar': False,
        'ShowTabView': False, 'ContainerShowSidebar': False,
    }
    store['.']['icvp'] = {
        'viewOptionsVersion': 1, 'backgroundType': 2,
        'backgroundColorRed': 1.0, 'backgroundColorGreen': 1.0, 'backgroundColorBlue': 1.0,
        'backgroundImageAlias': Alias.for_file(str(background)).to_bytes(),
        'iconSize': 104.0, 'textSize': 13.0,
        'labelOnBottom': True, 'showItemInfo': False,
        'showIconPreview': True, 'arrangeBy': 'none',
        'gridOffsetX': 0.0, 'gridOffsetY': 0.0, 'gridSpacing': 100.0,
        'scrollPositionX': 0.0, 'scrollPositionY': 0.0,
    }
    store['.']['icvl'] = ('type', 'icnv')
    store['.']['vSrn'] = ('long', 1)
    # Raise icon centers so the visible icon and its filename share the card center.
    store['MediaLens.app']['Iloc'] = (220, 232)
    store['Applications']['Iloc'] = (540, 232)
