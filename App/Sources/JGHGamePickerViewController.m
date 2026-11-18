#import "JGHGamePickerViewController.h"
#import "JGHAppConfig.h"

@interface JGHGamePickerViewController () <UISearchBarDelegate>
@property (nonatomic, strong) NSArray<NSDictionary *> *apps;
@property (nonatomic, strong) NSArray<NSDictionary *> *filteredApps;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation JGHGamePickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"添加游戏";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"AppCell"];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(done)];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.definesPresentationContext = YES;

    self.apps = [self installedApplications];
    self.filteredApps = self.apps;
}

- (NSArray<NSDictionary *> *)installedApplications {
    NSMutableArray *result = [NSMutableArray array];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
    NSArray *proxies = nil;
    if ([workspace respondsToSelector:@selector(allApplications)]) {
        proxies = [workspace performSelector:@selector(allApplications)];
    }
    for (id proxy in proxies) {
        NSString *bid = [proxy respondsToSelector:@selector(applicationIdentifier)]
            ? [proxy performSelector:@selector(applicationIdentifier)] : nil;
        NSString *name = [proxy respondsToSelector:@selector(localizedName)]
            ? [proxy performSelector:@selector(localizedName)] : nil;
        if (bid.length == 0) continue;
        if ([bid hasPrefix:@"com.apple."]) continue; // 隐藏系统 App
        [result addObject:@{@"bundleID": bid, @"name": name ?: bid}];
    }
    [result sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    return result;
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredApps = self.apps;
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSDictionary *app in self.apps) {
            if ([app[@"name"] rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [app[@"bundleID"] rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [filtered addObject:app];
            }
        }
        self.filteredApps = filtered;
    }
    [self.tableView reloadData];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppCell" forIndexPath:indexPath];
    NSDictionary *app = self.filteredApps[indexPath.row];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text = app[@"bundleID"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *app = self.filteredApps[indexPath.row];
    [JGHAppConfig addGame:app];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
