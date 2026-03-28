from django.urls import path

from .views import (
    AdminClinicReferralLinkAPIView,
    AdminReferralsListAPIView,
    AdminReferralsSummaryAPIView,
    MarkReferralConvertedAPIView,
    MarkReferralPaidAPIView,
    MyReferralsAPIView,
)

urlpatterns = [
    path("my-referrals/", MyReferralsAPIView.as_view(), name="referrals-my-referrals"),
    path("admin/list/", AdminReferralsListAPIView.as_view(), name="referrals-admin-list"),
    path("admin/link/", AdminClinicReferralLinkAPIView.as_view(), name="referrals-admin-link"),
    path(
        "<uuid:referral_id>/mark-converted/",
        MarkReferralConvertedAPIView.as_view(),
        name="referrals-mark-converted",
    ),
    path(
        "<uuid:referral_id>/mark-paid/",
        MarkReferralPaidAPIView.as_view(),
        name="referrals-mark-paid",
    ),
    path("admin/summary/", AdminReferralsSummaryAPIView.as_view(), name="referrals-admin-summary"),
]
