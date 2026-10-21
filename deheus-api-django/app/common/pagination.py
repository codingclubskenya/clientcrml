from rest_framework.pagination import PageNumberPagination


class TenantPagination(PageNumberPagination):
    page_size = 100
    max_page_size = 500
    page_size_query_param = 'page_size'
