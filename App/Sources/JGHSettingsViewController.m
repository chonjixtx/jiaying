#import "JGHSettingsViewController.h"
#import "JGHAppConfig.h"

@interface JGHSettingsViewController ()
@property (nonatomic, strong) NSMutableDictionary *settings;
@end

@implementation JGHSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"功能设置";
    self.settings = [[JGHAppConfig loadSettings] mutableCopy];
}

- (void)save {
    [JGHAppConfig saveSettings:self.settings];
}

#pragma mark - Helpers

- (UISwitch *)switchWithKey:(NSString *)key {
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = [self.settings[key] boolValue];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    sw.tag = [key hash];
    return sw;
}

- (UISlider *)sliderWithKey:(NSString *)key min:(float)min max:(float)max {
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.value = [self.settings[key] floatValue];
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    slider.tag = [key hash];
    return slider;
}

- (void)switchChanged:(UISwitch *)sender {
    NSString *key = sender.tag == [@"enabled" hash] ? @"enabled"
                  : sender.tag == [@"streamerMode" hash] ? @"streamerMode"
                  : @"scrollZoom";
    self.settings[key] = @(sender.on);
    [self save];
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *key = @"pointerSize";
    if (sender.tag == [@"mouseSensitivity" hash]) key = @"mouseSensitivity";
    else if (sender.tag == [@"scrollStep" hash]) key = @"scrollStep";
    self.settings[key] = @(sender.value);
    [self save];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"映射";
    if (section == 1) return @"鼠标指针";
    return @"主播模式";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 5;
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"SettingCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0) {
        cell.textLabel.text = @"启用按键映射";
        cell.accessoryView = [self switchWithKey:@"enabled"];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"指针灵敏度";
            cell.accessoryView = [self sliderWithKey:@"mouseSensitivity" min:0.2f max:3.0f];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"指针大小";
            cell.accessoryView = [self sliderWithKey:@"pointerSize" min:6.0f max:40.0f];
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"滚轮方向";
            UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"竖向", @"横向"]];
            seg.selectedSegmentIndex = [self.settings[@"scrollOrientation"] isEqualToString:@"horizontal"] ? 1 : 0;
            [seg addTarget:self action:@selector(orientationChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = seg;
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"每格滚动距离";
            cell.accessoryView = [self sliderWithKey:@"scrollStep" min:1.0f max:20.0f];
        } else {
            cell.textLabel.text = @"滚轮缩放";
            cell.accessoryView = [self switchWithKey:@"scrollZoom"];
        }
    } else {
        cell.textLabel.text = @"主播模式（录屏时隐藏悬浮按键）";
        cell.accessoryView = [self switchWithKey:@"streamerMode"];
    }
    return cell;
}

- (void)orientationChanged:(UISegmentedControl *)sender {
    self.settings[@"scrollOrientation"] = sender.selectedSegmentIndex == 1 ? @"horizontal" : @"vertical";
    [self save];
}

@end
