#import "JGHGameListViewController.h"
#import "JGHAppConfig.h"
#import "JGHGamePickerViewController.h"
#import "JGHSettingsViewController.h"

@interface JGHGameListViewController ()
@property (nonatomic, strong) NSArray<NSDictionary *> *games;
@end

@implementation JGHGameListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"佳影游戏厅";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                          target:self
                                                                                          action:@selector(addGame)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"设置"
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(openSettings)];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"GameCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.games = [JGHAppConfig loadGames];
    [self.tableView reloadData];
}

- (void)addGame {
    JGHGamePickerViewController *picker = [[JGHGamePickerViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openSettings {
    JGHSettingsViewController *settings = [[JGHSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [self.navigationController pushViewController:settings animated:YES];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.games.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GameCell" forIndexPath:indexPath];
    NSDictionary *game = self.games[indexPath.row];
    cell.textLabel.text = game[@"name"] ?: game[@"bundleID"];
    cell.detailTextLabel.text = game[@"bundleID"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *game = self.games[indexPath.row];
    NSString *bundleID = game[@"bundleID"];
    if (bundleID.length == 0) return;

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
    if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
        [workspace performSelector:@selector(openApplicationWithBundleID:) withObject:bundleID];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法启动"
                                                                       message:@"当前环境不支持通过 Bundle ID 启动应用。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *bid = self.games[indexPath.row][@"bundleID"];
        [JGHAppConfig removeGameWithBundleID:bid];
        self.games = [JGHAppConfig loadGames];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

@end
