from django.urls import path

from .views import PublicReferralLookupAPIView

urlpatterns = [
    path("<str:codigo>/", PublicReferralLookupAPIView.as_view(), name="referrals-public-lookup"),
]

