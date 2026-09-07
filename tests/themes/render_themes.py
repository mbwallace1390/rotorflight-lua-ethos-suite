"""Execute unchanged suite engine and user themes with a deterministic desktop LCD.

Pillow previews use desktop fonts: useful for layout review, not radio screenshots.
Run with Python containing Pillow and lupa (or put lupa in build/test-deps).
"""
from pathlib import Path
import argparse
import json
import math
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'build/test-deps'))
from lupa.lua54 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

THEMES = ('aegis', 'america250', 'libertyops250', 'mwrc', 'singularity', 'zafira')
PHASES = ('preflight', 'inflight', 'postflight')
SIZES = {'FONT_XXS': 12, 'FONT_XS': 16, 'FONT_S': 20, 'FONT_STD': 24,
         'FONT_L': 28, 'FONT_XL': 36, 'FONT_XXL': 48, 'FONT_XXXXL': 64}


class Radio:
    def __init__(self, width=800, height=480, dark=True, themed=False):
        self.width, self.height, self.dark = width, height, dark
        self.image = Image.new('RGB', (width, height), '#14161a')
        self.draw = ImageDraw.Draw(self.image)
        self.color = (238, 241, 245)
        self.font = 24
        self.fonts = {v: ImageFont.truetype('C:/Windows/Fonts/arial.ttf', v) for v in SIZES.values()}
        self.texts, self.errors, self.loads = [], [], []
        self.calls = 0
        self.native_colors = {}
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        g = self.lua.globals()
        g.py_lcd = self.lcd
        g.py_read = self.read
        g.py_print = lambda *args: self.errors.append(' '.join(map(str, args)))
        for name, size in SIZES.items():
            g[name] = size
        for i, name in enumerate(('CATEGORY_TELEMETRY_SENSOR', 'CATEGORY_SYSTEM', 'CATEGORY_CHANNEL', 'MAIN_VOLTAGE', 'RSSI', 'TEXT_LEFT', 'TEXT_RIGHT', 'TEXT_CENTERED', 'LEFT', 'RIGHT', 'CENTERED'), 100):
            g[name] = i
        if themed:
            names = ('DEFAULT_COLOR','DEFAULT_BGCOLOR','FOCUS_BGCOLOR','FOCUS_COLOR','PRIMARY_COLOR',
                     'PRIMARY_BGCOLOR','SECONDARY_COLOR','SECONDARY_BGCOLOR','HIGHLIGHT_COLOR',
                     'HIGHLIGHT_CONTRASTING_COLOR','DISABLE_COLOR','ERROR_COLOR','WARNING_COLOR',
                     'ACTIVE_COLOR','INACTIVE_COLOR','BUTTON_BORDER_ACTIVE_COLOR','BUTTON_BORDER_COLOR',
                     'SAFE_COLOR','SAFE_CONTRASTING_COLOR','PAGE_BGCOLOR')
            for i, name in enumerate(names, 200):
                g['THEME_' + name] = i
                self.native_colors[i] = ((0x14161A if dark else 0xF5F6F8) if ('BGCOLOR' in name)
                    else (0xEEF1F5 if dark else 0x202834))
        g.WIDTH, g.HEIGHT, g.DARK = width, height, dark
        g.THEMED = themed
        self.lua.execute('''
          print = function(...) py_print(...) end
          loadfile = function(path)
            local content, err = py_read(path)
            if not content then return nil, err end
            return load(content, '@' .. path, 't', _G)
          end
          TEST_TIME = 100
          os.clock = function() return TEST_TIME end
          os.time = function() return 1788786000 end
          lcd = {}
          for _, name in ipairs({'color','font','drawText','drawNumber','drawLine',
            'drawRectangle','drawFilledRectangle','drawCircle','drawFilledCircle',
            'drawTriangle','drawFilledTriangle','drawAnnulusSector','drawPoint',
            'drawBitmap','drawMask','setClipping','resetClipping','invalidate',
            'resetFocusTimeout','pen'}) do
            lcd[name] = function(...) return py_lcd(name, ...) end
          end
          lcd.RGB = function(r,g,b,a) return math.floor(r)*65536+math.floor(g)*256+math.floor(b) end
          lcd.GREY = function(v) return lcd.RGB(v,v,v) end
          lcd.getTextSize = function(s) return py_lcd('getTextSize', s) end
          lcd.getWindowSize = function() return WIDTH,HEIGHT end
          lcd.darkMode = function() return DARK end
          lcd.isVisible = function() return true end
          lcd.hasFocus = function() return false end
          if THEMED then lcd.themeColor = function(key) return py_lcd('themeColor',key) end end
          lcd.loadBitmap = function() return nil end
          lcd.loadMask = function() return nil end
          system = {
            getVersion=function() return {major=THEMED and 26 or 1,minor=THEMED and 1 or 6,revision=5,board='X20PRO',simulation=true} end,
            getSource=function(spec)
              if type(spec)=='table' and (spec.appId==0xF010 or spec.category==CATEGORY_SYSTEM) then
                return {value=function() return spec.category==CATEGORY_SYSTEM and 8.1 or 98 end,
                        state=function() return true end,unit=function() return 0 end}
              end
              return nil
            end,
            voltageRange=function() return 6.6,8.4 end,
            getLocale=function() return 'en' end
          }
          model = {name=function() return 'Rotorflight 700' end,
                   getInfo=function() return {name='Rotorflight 700'} end,
                   getBitmap=function() return nil end}
          i18n = {}
        ''')
        self.context = self.load('widgets/dashboard/context.lua')
        self.engine = self.load('widgets/dashboard/engine.lua')

    def read(self, path):
        path = str(path)
        self.loads.append(path)
        path = path.removeprefix('SCRIPTS:/rfsuite/').removeprefix('rfsuite/')
        file = ROOT / 'src/rfsuite' / path
        if not file.is_file():
            return None, f'missing fixture file: {path}'
        source = file.read_text(encoding='utf-8-sig')
        source = re.sub(r'@i18n\(([^)]+)\)@', lambda m: m[1].split('.')[-1].replace('_', ' ').upper(), source)
        return source, None

    def load(self, path):
        return self.lua.eval('function(path) return assert(loadfile(path))() end')(path)

    def table(self, value):
        if isinstance(value, dict):
            return self.lua.table_from({k: self.table(v) for k,v in value.items()})
        if isinstance(value, (list, tuple)):
            return self.lua.table_from([self.table(v) for v in value])
        return value

    def lcd(self, op, *args):
        self.calls += 1
        if op == 'themeColor': return self.native_colors[args[0]]
        if op == 'color':
            val = args[0]
            if isinstance(val, (int, float)):
                val = int(val); self.color = ((val >> 16)&255, (val >> 8)&255, val&255)
            return
        if op == 'font':
            self.font = int(args[0]); return
        font = self.fonts.get(self.font, self.fonts[24])
        if op == 'getTextSize':
            return math.ceil(font.getlength(str(args[0]))), self.font
        if op in ('drawText','drawNumber'):
            x,y,txt = args[:3]; txt = str(txt)
            self.texts.append((float(x),float(y),txt,self.font,math.ceil(font.getlength(txt))))
            self.draw.text((x,y),txt,font=font,fill=self.color,anchor='lt'); return
        if op == 'drawLine':
            self.draw.line(tuple(args[:4]),fill=self.color,width=max(1,int(args[4])) if len(args)>4 and args[4] else 1); return
        if op in ('drawRectangle','drawFilledRectangle'):
            x,y,w,h = args[:4]
            if w < 0 or h < 0:
                raise AssertionError(f'negative rectangle {op}: {args}')
            if w == 0 or h == 0: return
            self.draw.rectangle((x,y,x+w-1,y+h-1),fill=self.color if op=='drawFilledRectangle' else None,
                                outline=None if op=='drawFilledRectangle' else self.color,
                                width=max(1,int(args[4])) if len(args)>4 and args[4] else 1); return
        if op in ('drawCircle','drawFilledCircle'):
            x,y,r = args[:3]
            if r <= 0: return
            self.draw.ellipse((x-r,y-r,x+r,y+r), fill=self.color if op=='drawFilledCircle' else None,
                              outline=self.color,width=1); return
        if op in ('drawTriangle','drawFilledTriangle'):
            self.draw.polygon(tuple(args[:6]), fill=self.color if op=='drawFilledTriangle' else None,outline=self.color); return
        if op=='drawAnnulusSector':
            x,y,inner,outer,start,end=args[:6]
            self.draw.arc((x-outer,y-outer,x+outer,y+outer),start-90,end-90,fill=self.color,width=max(1,int(outer-inner))); return
        if op=='drawPoint': self.draw.point(args[:2],fill=self.color)

    def widget(self, phase, scenario='connected', fahrenheit=False):
        values = dict(connected=True, isArmed=phase=='inflight', flightmodeState=phase, mspTransport='sport',
                      mcuId='TEST700', craftName='ROTORFLIGHT 700', rfVersion='12.09',
                      timerLive=184, governorState=4 if phase=='inflight' else 0,
                      voltage=48.2,current=52.4,consumption=1450,rpm=2150,fuelPercent=72,
                      becVoltage=7.4,tempEsc=62,tempMcu=39,linkQuality=80,throttlePercent=65,
                      pidProfile=1,rateProfile=2,batteryProfile=1,armDisableFlags=0,
                      batteryConfig={'cellCount':12},modelStats={'flightcount':42,'totalflighttime':9460,'lastflighttime':184},
                      settingsSnapshot={'general':{'temperature_unit':1 if fahrenheit else 0,'txbatt_type':0},'dashboard':{}},
                      dashboardStats={key:{'min':lo,'max':hi,'avg':avg,'sum':avg*20,'count':20}
                         for key,lo,hi,avg in [('voltage',44.2,50.4,47.2),('cell_voltage',44.2/12,4.2,47.2/12),('current',0,121,48),('rpm',2000,2230,2150),
                                              ('smartfuel',28,100,64),('temp_esc',30,86,64),('bec_voltage',7.2,7.5,7.4),('consumption',0,3420,1500),('vfr',87,100,98),('watts',0,4800,2400)]})
        if scenario=='offline': values.update(connected=False,isArmed=False)
        if scenario=='missing':
            for key in ('voltage','current','consumption','rpm','fuelPercent','becVoltage','tempEsc','tempMcu','linkQuality','throttlePercent','pidProfile','rateProfile','batteryProfile'):
                values.pop(key,None)
        if scenario=='warnings': values.update(becVoltage=6.1,tempEsc=155,fuelPercent=14,current=145)
        return self.table(values)

    def render(self, theme, phase, scenario='connected', fahrenheit=False):
        widget=self.widget(phase,scenario,fahrenheit)
        self.context.setWidget(widget)
        self.context.widgets.dashboard.setPreferences(self.table({'rpm_max':3400,'fuel_warn':30,'bec_min':6.5,'bec_warn':7.0,'esc_warn':110,'esc_max':150,'link_warn':50}),f'widgets/dashboard/themes/{theme}')
        theme_def=self.load(f'widgets/dashboard/themes/{theme}/init.lua')
        state_def=self.load(f'widgets/dashboard/themes/{theme}/{phase}.lua')
        # The real engine's incremental loading and cold-start paint path.
        for _ in range(8):
            self.lua.globals().TEST_TIME += 0.25
            self.engine.wakeup(widget,state_def,self.width,self.height)
            self.texts.clear()
            ready=self.engine.paint(widget,theme_def,state_def,phase,self.width,self.height)
        if self.errors: raise AssertionError('\n'.join(self.errors))
        if not ready: raise AssertionError('engine did not finish rendering')
        if len(self.texts)<5: raise AssertionError('theme rendered too little content')
        return state_def, widget


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--output', default='artifacts/theme-previews')
    p.add_argument('--themes',nargs='+',default=THEMES)
    p.add_argument('--phases',nargs='+',default=PHASES,choices=PHASES)
    p.add_argument('--sizes',nargs='+',default=['800x480','784x294'])
    p.add_argument('--scenarios',nargs='+',default=['connected','offline','missing','warnings'])
    p.add_argument('--modes',nargs='+',default=['dark16'],choices=['dark16','dark26','light26'])
    args=p.parse_args()
    output=ROOT/args.output; output.mkdir(parents=True,exist_ok=True)
    results=[]
    for size in args.sizes:
        width,height=map(int,size.split('x'))
        for mode in args.modes:
            for theme in args.themes:
                for phase in args.phases:
                    for scenario in args.scenarios:
                        r=Radio(width,height,dark=mode!='light26',themed=mode!='dark16')
                        try:
                            r.render(theme,phase,scenario)
                            if scenario=='connected':
                                r.image.save(output/f'{theme}-{phase}-{size}-{mode}.png')
                            results.append(dict(theme=theme,phase=phase,size=size,mode=mode,scenario=scenario,ok=True,
                                                overflow=[t for t in r.texts if t[0]<-1 or t[1]<-1 or t[0]+t[4]>width+2 or t[1]+t[3]>height+2]))
                        except Exception as e:
                            results.append(dict(theme=theme,phase=phase,size=size,mode=mode,scenario=scenario,ok=False,error=str(e)))
                            print(f'FAIL {theme} {phase} {size} {mode} {scenario}: {e}')
    (output/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    failures=sum(not r['ok'] for r in results)
    print(f'{len(results)-failures}/{len(results)} theme/phase/size/scenario cases passed')
    return 1 if failures else 0

if __name__=='__main__':
    raise SystemExit(main())
