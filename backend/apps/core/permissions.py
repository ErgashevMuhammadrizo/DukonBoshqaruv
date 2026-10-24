from rest_framework.permissions import BasePermission, IsAuthenticated
from .models import Store


class ActiveStoreUser(IsAuthenticated):
    """Reject all shop API requests for a store blocked by a superadmin."""
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        user = request.user
        if user.is_superuser:
            return True
        active = Store.objects.filter(owner_id=user.pk).values_list('is_active', flat=True).first()
        return active is None or active
