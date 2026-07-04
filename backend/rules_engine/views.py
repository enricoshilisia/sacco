from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission
from loans.models import LoanProduct

from .models import LoanEligibilityPolicy
from .serializers import LoanEligibilityPolicySerializer


class LoanEligibilityPolicyView(APIView):
    """
    One eligibility policy per loan product. GET 404s if the product has
    no policy configured yet (mirrors members.views.MyMemberView's "not
    yet linked -> 404" shape). PUT/PATCH get-or-create the policy row
    then update it - a product's policy doesn't exist until staff first
    configure it.
    """

    permission_classes = [IsAuthenticated, require_permission("loans.manage_eligibility_policy")]

    def get(self, request, product_id):
        policy = LoanEligibilityPolicy.objects.filter(product_id=product_id).first()
        if policy is None:
            return Response({"detail": "No eligibility policy configured for this product."}, status=status.HTTP_404_NOT_FOUND)
        return Response(LoanEligibilityPolicySerializer(policy).data)

    def put(self, request, product_id):
        return self._upsert(request, product_id, partial=False)

    def patch(self, request, product_id):
        return self._upsert(request, product_id, partial=True)

    def _upsert(self, request, product_id, partial):
        product = generics.get_object_or_404(LoanProduct, pk=product_id)
        policy, _ = LoanEligibilityPolicy.objects.get_or_create(product=product)
        serializer = LoanEligibilityPolicySerializer(policy, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
