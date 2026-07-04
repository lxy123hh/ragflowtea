import message from '@/components/ui/message';
import chatService from '@/services/next-chat-service';
import { useMutation } from '@tanstack/react-query';

const DEFAULT_TEA_IMAGE_PROMPT =
  '你是茶园图片识别助手。请只根据图片中可见内容进行描述，不要直接给最终农技处方。' +
  '请判断图片是否属于茶园、茶树、鲜叶、干茶、茶汤或茶具场景。' +
  '如果不是茶相关场景，请明确说明。' +
  '请输出：1. 可见现象；2. 疑似问题；3. 需要进一步确认的信息；4. 适合知识库检索的关键词。';

export function useImage2Text() {
  const { mutateAsync, isPending } = useMutation({
    mutationFn: async (file: File) => {
      const formData = new FormData();

      formData.append('file', file);
      formData.append('prompt', DEFAULT_TEA_IMAGE_PROMPT);

      const { data } = await chatService.image2text(
        {
          data: formData,
        },
        true,
      );

      if (data?.code !== 0) {
        const errorMessage = data?.message || '图片识别失败';
        message.error(errorMessage);
        throw new Error(errorMessage);
      }

      return data?.data?.text || '';
    },
  });

  return {
    image2text: mutateAsync,
    image2textLoading: isPending,
  };
}
