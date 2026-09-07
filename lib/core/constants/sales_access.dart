class SalesAccess {
  static bool isAdmin(int? role) => role == 1;

  static bool canViewSalesFlow(int? role) => role != null;

  static bool canEditSalesFlow(int? role) {
    if (role == null) return false;
    return role == 1 || role == 2 || role == 3 || role == 4 || role == 5;
  }

  static bool canCheckout(int? role) {
    if (role == null) return false;
    return role == 1 || role == 3 || role == 4 || role == 5;
  }

  static bool canFinishPendingOrder(int? role) {
    if (role == null) return false;
    return role == 1 || role == 5;
  }

  static bool isViewOnly(int? role) => !canEditSalesFlow(role);
}
